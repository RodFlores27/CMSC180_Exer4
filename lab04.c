#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netdb.h>
#include <pthread.h>
#include <sched.h>

#define MAX_SLAVES 32
#define MAX_IP_LEN 64
#define BUFFER_SIZE 1024
#define CONFIG_FILE "config.txt"

// Structure to store slave information
typedef struct
{
    char ip[MAX_IP_LEN]; // IP address
    int port;            // port number
} SlaveInfo;

// Function to read the configuration file
// Opens and reads the config.txt file line by line
// Parses each line to extract IP, port, and role(master / slave)
// For slaves : stores the master's IP address
// For master : stores all slave information in the slaves array
// Returns the number of slaves found

int read_config(char master_ip[MAX_IP_LEN], SlaveInfo slaves[], int *num_slaves, int is_slave)
{
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (fp == NULL)
    {
        perror("Error opening config file");
        return -1;
    }

    char line[256];
    int slave_count = 0;

    while (fgets(line, sizeof(line), fp))
    {
        // Skip comments and empty lines
        if (line[0] == '#' || line[0] == '\n')
            continue;

        char ip[MAX_IP_LEN];
        int port;
        char role[10];

        if (sscanf(line, "%s %d %s", ip, &port, role) == 3)
        {
            if (strcmp(role, "master") == 0)
            {
                if (is_slave)
                {
                    strcpy(master_ip, ip); // copy master ip
                }
            }
            else if (strcmp(role, "slave") == 0)
            {
                if (!is_slave) // if master
                {
                    strcpy(slaves[slave_count].ip, ip);
                    slaves[slave_count].port = port;
                    slave_count++;
                }
            }
        }
    }

    fclose(fp);
    *num_slaves = slave_count;
    return 0;
}

// Function to run as master
int run_as_master(int n, int port, int num_slaves, SlaveInfo slaves[])
{
    printf("Running as master with n=%d, port=%d, slaves=%d\n", n, port, num_slaves);

    // Create a non-zero n × n square matrix M with random positive integers
    int **M = (int **)malloc(n * sizeof(int *));
    for (int i = 0; i < n; i++)
    {
        M[i] = (int *)malloc(n * sizeof(int));
        for (int j = 0; j < n; j++)
        {
            M[i][j] = (rand() % 9) + 1; // Random numbers from 1 to 9
        }
    }

    // Function to print an n x n matrix
    void print_matrix(int **M, int n)
    {
        printf("Matrix contents:\n");
        for (int i = 0; i < n; i++)
        {
            for (int j = 0; j < n; j++)
            {
                printf("%d ", M[i][j]);
            }
            printf("\n");
        }
    }

    printf("My Matrix: \n\n");
    print_matrix(M, n); // Print the matrix for verification

    // Calculate rows per slave
    int rows_per_slave = n / num_slaves;

    // Start timer
    struct timespec time_before, time_after;
    clock_gettime(CLOCK_MONOTONIC, &time_before);

    // For each slave, create a socket, connect, and send data
    for (int s = 0; s < num_slaves; s++)
    {
        // Create socket
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0)
        {
            perror("Socket creation failed");
            continue;
        }

        // Set up server address
        struct sockaddr_in server_addr;
        memset(&server_addr, 0, sizeof(server_addr));
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(slaves[s].port);

        if (inet_pton(AF_INET, slaves[s].ip, &server_addr.sin_addr) <= 0)
        {
            perror("Invalid address");
            close(sock);
            continue;
        }

        // Connect to server
        if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0)
        {
            perror("Connection failed");
            close(sock);
            continue;
        }

        printf("Connected to slave %d (%s:%d)\n", s, slaves[s].ip, slaves[s].port);

        // Send matrix dimensions
        send(sock, &n, sizeof(int), 0);

        // Send row start and count
        int start_row = s * rows_per_slave;
        int num_rows = (s == num_slaves - 1) ? (n - start_row) : rows_per_slave;
        send(sock, &start_row, sizeof(int), 0);
        send(sock, &num_rows, sizeof(int), 0);

        // Send matrix portion
        for (int i = start_row; i < start_row + num_rows; i++)
        {
            send(sock, M[i], n * sizeof(int), 0);
        }

        // Receive acknowledgment
        char ack[4];
        recv(sock, ack, 3, 0);
        ack[3] = '\0';
        printf("Received from slave %d: %s\n", s, ack);

        close(sock);
    }

    // End timer
    clock_gettime(CLOCK_MONOTONIC, &time_after);
    double elapsed_time = (time_after.tv_sec - time_before.tv_sec) +
                          (time_after.tv_nsec - time_before.tv_nsec) / 1000000000.0;

    printf("\nMaster execution time: %0.9f seconds\n", elapsed_time);

    // Free matrix memory
    for (int i = 0; i < n; i++)
    {
        free(M[i]);
    }
    free(M);

    return 0;
}

// Function to run as slave
int run_as_slave(int port, char master_ip[MAX_IP_LEN])
{
    printf("Running as slave with port=%d, master=%s\n", port, master_ip);

    // Create socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0)
    {
        perror("Socket creation failed");
        return -1;
    }

    // Set socket options to reuse address
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
    {
        perror("Setsockopt failed");
        return -1;
    }

    // Bind socket to port
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0)
    {
        perror("Bind failed");
        return -1;
    }

    // Start listening
    if (listen(server_fd, 3) < 0)
    {
        perror("Listen failed");
        return -1;
    }

    printf("Slave listening on port %d...\n", port);

    // Accept incoming connection
    struct sockaddr_in client_addr;
    socklen_t client_addr_len = sizeof(client_addr);

    int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_addr_len);
    if (client_fd < 0)
    {
        perror("Accept failed");
        return -1;
    }

    char client_ip[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
    printf("Connection accepted from %s:%d\n", client_ip, ntohs(client_addr.sin_port));

    // Start timer
    struct timespec time_before, time_after;
    clock_gettime(CLOCK_MONOTONIC, &time_before);

    // Receive matrix dimensions
    int n;
    recv(client_fd, &n, sizeof(int), 0);

    // Receive row start and count
    int start_row, num_rows;
    recv(client_fd, &start_row, sizeof(int), 0);
    recv(client_fd, &num_rows, sizeof(int), 0);

    printf("Receiving submatrix: n=%d, start_row=%d, num_rows=%d\n", n, start_row, num_rows);

    // Allocate memory for submatrix
    int **submatrix = (int **)malloc(num_rows * sizeof(int *));
    for (int i = 0; i < num_rows; i++)
    {
        submatrix[i] = (int *)malloc(n * sizeof(int));
        recv(client_fd, submatrix[i], n * sizeof(int), 0);
    }

    // Print a small portion of the submatrix for verification (if matrix is large)
    printf("Received submatrix (showing up to 5x5):\n");
    for (int i = 0; i < (num_rows < 5 ? num_rows : 5); i++)
    {
        for (int j = 0; j < (n < 5 ? n : 5); j++)
        {
            printf("%d ", submatrix[i][j]);
        }
        printf("...\n");
    }

    // Send acknowledgment
    send(client_fd, "ack", 3, 0);

    // End timer
    clock_gettime(CLOCK_MONOTONIC, &time_after);
    double elapsed_time = (time_after.tv_sec - time_before.tv_sec) +
                          (time_after.tv_nsec - time_before.tv_nsec) / 1000000000.0;

    printf("\nSlave execution time: %0.9f seconds\n", elapsed_time);

    // Clean up
    for (int i = 0; i < num_rows; i++)
    {
        free(submatrix[i]);
    }
    free(submatrix);
    close(client_fd);
    close(server_fd);

    return 0;
}

int main(int argc, char *argv[])
{
    // Check command line arguments
    if (argc != 4)
    {
        printf("Usage: %s <n> <port> <status>\n", argv[0]);
        printf("  n: size of square matrix (for master), ignored for slave\n");
        printf("  port: port number to listen on\n");
        printf("  status: 0 for master, 1 for slave\n");
        return 1;
    }

    int n = atoi(argv[1]);      // Matrix size
    int port = atoi(argv[2]);   // Port number
    int status = atoi(argv[3]); // Status (0 for master, 1 for slave)

    // Seed random number generator
    srand(time(NULL));

    // Read configuration file
    SlaveInfo slaves[MAX_SLAVES];
    int num_slaves = 0;
    char master_ip[MAX_IP_LEN] = "";

    if (read_config(master_ip, slaves, &num_slaves, status) != 0)
    {
        return 1;
    }

    // Run as master or slave
    if (status == 0)
    {
        // Make sure we have slaves
        if (num_slaves == 0)
        {
            printf("No slaves found in configuration file\n");
            return 1;
        }
        run_as_master(n, port, num_slaves, slaves);
    }
    else
    {
        // Make sure we have master IP
        if (strlen(master_ip) == 0)
        {
            printf("No master found in configuration file\n");
            return 1;
        }
        run_as_slave(port, master_ip);
    }

    return 0;
}