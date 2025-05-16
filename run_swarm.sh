#!/bin/bash

# Script to deploy and run lab04 on the ICS Compute Swarm
# Edit the makefile if you want to use lab04_core_affine instead of lab04

# Number of drones to use
NUM_DRONES=4

# Matrix size
N=20000

# Master port
MASTER_PORT=8000

# Slave port base
SLAVE_PORT=8000

# Program selection: Set to either "lab04" or "lab04_core_affine"
PROGRAM="lab04"

# Compile the program
make

# Update config.txt with actual IP addresses and ports
# Get local IP address
LOCAL_IP=$(hostname -I | cut -d' ' -f1)

# Array of drone IPs
DRONES=(
    "10.0.9.182"  # drone01
    "10.0.9.183"  # drone02
    "10.0.9.79"   # drone03
    "10.0.9.82"   # drone04
    # Add more if needed
)

# Create config file for swarm deployment - DYNAMICALLY
cat > config.txt << EOF
# Configuration file for lab04 - ICS Compute Swarm
# Format: IP_ADDRESS PORT_NUMBER ROLE

# Master (lab PC)
${LOCAL_IP} ${MASTER_PORT} master

# Slaves (compute drones)
EOF

# Add drone entries dynamically based on NUM_DRONES
for i in $(seq 0 $((NUM_DRONES-1)))
do
    if [ $i -lt ${#DRONES[@]} ]; then
        echo "${DRONES[$i]} ${SLAVE_PORT} slave" >> config.txt
    fi
done

# Copy program to drones and start slaves
echo "Starting slaves on compute drones using $PROGRAM..."
for i in $(seq 0 $((NUM_DRONES-1)))
do
    if [ $i -ge ${#DRONES[@]} ]; then
        echo "Warning: Requested $NUM_DRONES drones but only ${#DRONES[@]} are defined"
        break
    fi
    
    drone=${DRONES[$i]}
    echo "Copying to drone at ${drone}..."
    scp $PROGRAM config.txt cmsc180@${drone}:.
    
    # Start slave on drone in background
    ssh -f cmsc180@${drone} "cd ~; ./$PROGRAM ${N} ${SLAVE_PORT} 1" &

    sleep 1
done

# Wait for slaves to start
echo "Waiting for slaves to initialize..."
sleep 5

# Run master
echo "Starting master with n=${N} and $NUM_DRONES slaves using $PROGRAM..."
./$PROGRAM ${N} ${MASTER_PORT} 0

# Kill remote slaves after master completes (optional cleanup)
echo "Cleaning up remote slaves..."
for i in $(seq 0 $((NUM_DRONES-1)))
do
    if [ $i -ge ${#DRONES[@]} ]; then
        break
    fi
    drone=${DRONES[$i]}
    ssh cmsc180@${drone} "pkill -f $PROGRAM" 2>/dev/null
done

echo "Done!"