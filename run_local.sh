#!/bin/bash

# Script to run lab04 in multiple terminals for local testing
# Edit the makefile if you want to use lab04_core_affine instead of lab04

# Compile the program
make

# Configuration variables
N=4                # Matrix size
NUM_SLAVES=4       # Number of slaves to launch
BASE_PORT=8000     # Base port number
MASTER_PORT=$BASE_PORT

# Generate config file based on slave count
echo "127.0.0.1 $MASTER_PORT master" > config.txt
for ((i=1; i<=NUM_SLAVES; i++)); do
    SLAVE_PORT=$((BASE_PORT + i))
    echo "127.0.0.1 $SLAVE_PORT slave" >> config.txt
done

# Start slaves in separate terminals
for ((i=1; i<=NUM_SLAVES; i++))
do
    # Calculate port for this slave
    SLAVE_PORT=$((BASE_PORT + i))
    
    echo "Starting slave $i on port $SLAVE_PORT"
    
    # Launch slave in new terminal
    # -fa 'Monospace -fs 12; this is for fonts 
    # ./lab04 $N $port 1; 1 means this is a slave (check main in lab04.c)
    xterm -fa 'Monospace' -fs 12 -e "./lab04 $N $SLAVE_PORT 1; read -p 'Press Enter to close...'" &
    # xterm -fa 'Monospace' -fs 12 -e "./lab04_core_affine $N $SLAVE_PORT 1; read -p 'Press Enter to close...'" &
done

# Wait for slaves to start
sleep 2

echo "Starting master on port $MASTER_PORT with $NUM_SLAVES slaves"

# Run master
./lab04 $N $MASTER_PORT 0