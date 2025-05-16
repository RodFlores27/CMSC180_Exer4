#!/bin/bash

# Test script for lab04 - runs the required test cases from the assignment

# Test matrix sizes
N_VALUES=(4)

# Number of slaves to test
T_VALUES=(2 3)

# Compile both versions
echo "Compiling programs..."
gcc -Wall -Wextra -pthread -o lab04 lab04.c
gcc -Wall -Wextra -pthread -o lab04_core_affine lab04_core_affine.c

# Function to run a single test
run_test() {
    local program=$1
    local n=$2
    local t=$3
    local run_num=$4
    
    echo "Running $program with n=$n, t=$t, run #$run_num"
    
    # Update config to have correct number of slaves
    cat > config.txt << EOF
# Auto-generated config for testing
127.0.0.1 8000 master
EOF
    
    # Add slaves in config.txt
    for ((i=1; i<=t; i++)); do
        echo "127.0.0.1 $((8000+i)) slave" >> config.txt
    done
    
    # Start slaves in background
    # $! is the PID of the last background process; these are stored in the slave_pids array.
    for ((i=1; i<=t; i++)); do
        ./$program $n $((8000+i)) 1 &
        slave_pids+=($!)
    done
    
    # Wait a moment for slaves to start
    sleep 2
    
    # Run master and capture timing
    ./$program $n 8000 0
    
    # Kill slaves
    for pid in "${slave_pids[@]}"; do
        kill $pid 2>/dev/null
    done
    
    # Clean up zombie processes
    wait
}

# Main test loop
echo "Starting tests..."
echo "Results will be written to test_results.txt"
echo > test_results.txt

echo "Test Results - $(date)" >> test_results.txt
echo "================================" >> test_results.txt

for n in "${N_VALUES[@]}"; do
    for t in "${T_VALUES[@]}"; do
        echo "" >> test_results.txt
        echo "Matrix size: $n, Slaves: $t" >> test_results.txt
        echo "----------------------------" >> test_results.txt
        echo "Regular version:" >> test_results.txt
        
        # Run regular version 3 times
        for run in 1 2 3; do
            echo "Run $run:" >> test_results.txt
            slave_pids=()
            run_test "lab04" $n $t $run >> test_results.txt 2>&1
        done
        
        # echo "" >> test_results.txt
        # echo "Core-affine version:" >> test_results.txt
        
        # # Run core-affine version 3 times
        # for run in 1 2 3; do
        #     echo "Run $run:" >> test_results.txt
        #     slave_pids=() # resets the slave_pids array 
        #     run_test "lab04_core_affine" $n $t $run >> test_results.txt 2>&1
        #     # So, 2>&1 tells the shell to redirect all error output (stderr) to the same place as standard output (stdout).
        # done
    done
done

echo "Testing complete! Check test_results.txt for detailed results."