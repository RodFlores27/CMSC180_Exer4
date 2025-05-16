#!/bin/bash

# Test script for lab04 swarm testing - distributed across drones

# Test matrix sizes
N_VALUES=(20000 25000 30000)

# Number of slaves to test
T_VALUES=(2 4 8 16)

# Get local IP address
LOCAL_IP=$(hostname -I | cut -d' ' -f1)

# Master port
MASTER_PORT=8000

# Slave port
SLAVE_PORT=8000

# Array of available drones
ALL_DRONES=(
    "10.0.9.182"  # drone01
    "10.0.9.183"  # drone02
    "10.0.9.79"   # drone03
    "10.0.9.82"   # drone04
    "10.0.9.184"  # drone05
    "10.0.9.83"   # drone06
    "10.0.9.186"  # drone07
    "10.0.9.89"   # drone08
    "10.0.9.88"   # drone09
    "10.0.9.91"   # drone10
    "10.0.9.92"   # drone11
    "10.0.9.93"   # drone12
    "10.0.9.96"   # drone13
    "10.0.9.97"   # drone14
    "10.0.9.98"   # drone15
    "10.0.9.100"  # drone16
)

# Function to run a single swarm test
run_swarm_test() {
    local program=$1
    local n=$2
    local t=$3
    local run_num=$4
    
    echo "Running swarm test: $program with n=$n, t=$t, run #$run_num" | tee -a swarm_test_results.txt
    
    # Select drones for this test
    SELECTED_DRONES=()
    for ((i=0; i<t; i++)); do
        SELECTED_DRONES+=(${ALL_DRONES[$i]})
    done
    
    # Create config file for this test
    cat > config.txt << EOF
# Auto-generated config for swarm testing
${LOCAL_IP} ${MASTER_PORT} master
EOF
    
    # Add selected drones as slaves
    for drone in "${SELECTED_DRONES[@]}"; do
        echo "${drone} ${SLAVE_PORT} slave" >> config.txt
    done
    
    # Deploy program to selected drones
    for drone in "${SELECTED_DRONES[@]}"; do
        echo "Deploying to ${drone}..."
        scp -q lab04 config.txt cmsc180@${drone}:. 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Failed to deploy to ${drone}"
            return 1
        fi
    done
    
    # Start slaves on drones
    slave_pids=()
    for drone in "${SELECTED_DRONES[@]}"; do
        echo "Starting slave on ${drone}..."
        ssh -f cmsc180@${drone} "cd ~; ./${program} ${n} ${SLAVE_PORT} 1" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Failed to start slave on ${drone}"
        fi
    done
    
    # Wait for slaves to start
    sleep 3
    
    # Run master and capture timing
    echo "Starting master..." | tee -a swarm_test_results.txt
    ./${program} ${n} ${MASTER_PORT} 0 | tee -a swarm_test_results.txt
    
    # Clean up slaves
    echo "Cleaning up slaves..."
    for drone in "${SELECTED_DRONES[@]}"; do
        ssh cmsc180@${drone} "pkill -f ${program}" 2>/dev/null
    done
    
    sleep 2
}

# Main test execution
echo "Starting swarm tests..." | tee swarm_test_results.txt
echo "Results will be written to swarm_test_results.txt" | tee -a swarm_test_results.txt
echo "====================================" | tee -a swarm_test_results.txt

# Verify drones are accessible
echo "Verifying drone connectivity..." | tee -a swarm_test_results.txt
for i in {0..3}; do
    drone=${ALL_DRONES[$i]}
    ssh -o ConnectTimeout=5 cmsc180@${drone} "echo 'Connected to ${drone}'" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Warning: Cannot connect to ${drone}" | tee -a swarm_test_results.txt
    fi
done

# Compile programs
echo "Compiling programs..." | tee -a swarm_test_results.txt
gcc -Wall -Wextra -pthread -o lab04 lab04.c
gcc -Wall -Wextra -pthread -o lab04_core_affine lab04_core_affine.c

# Run tests
for n in "${N_VALUES[@]}"; do
    for t in "${T_VALUES[@]}"; do
        # Check if we have enough drones
        if [ $t -gt ${#ALL_DRONES[@]} ]; then
            echo "Not enough drones for t=$t, skipping..." | tee -a swarm_test_results.txt
            continue
        fi
        
        echo "" | tee -a swarm_test_results.txt
        echo "Matrix size: $n, Slaves: $t" | tee -a swarm_test_results.txt
        echo "----------------------------" | tee -a swarm_test_results.txt
        echo "Regular version:" | tee -a swarm_test_results.txt
        
        # Run regular version 3 times
        for run in 1 2 3; do
            echo "Run $run:" | tee -a swarm_test_results.txt
            run_swarm_test "lab04" $n $t $run
        done
        
        echo "" | tee -a swarm_test_results.txt
        echo "Core-affine version:" | tee -a swarm_test_results.txt
        
        # Run core-affine version 3 times
        for run in 1 2 3; do
            echo "Run $run:" | tee -a swarm_test_results.txt
            run_swarm_test "lab04_core_affine" $n $t $run
        done
    done
done

echo "" | tee -a swarm_test_results.txt
echo "Testing complete! Check swarm_test_results.txt for detailed results." | tee -a swarm_test_results.txt