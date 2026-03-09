#!/bin/bash

################################################################################
# Setup Script for Network Connectivity Monitoring Tool
# 
# This script sets up the Docker containers and SSH keys for testing
# Run this script after Docker containers restart to reconfigure SSH access
################################################################################

set -e

echo "=========================================="
echo "  Setting up Test Environment"
echo "=========================================="

# Check if containers are running
echo "[1/5] Checking Docker containers..."
if ! docker ps | grep -q server; then
    echo "No containers running. Starting containers..."
    docker-compose up -d
    echo "Waiting for containers to start..."
    sleep 15
fi

# Configure each container with SSH key and ping
echo "[2/5] Configuring SSH keys and installing ping..."
for port in 2222 2223 2224; do
    container=$(docker ps -q --filter "publish=$port")
    if [[ -z "$container" ]]; then
        echo "  Warning: No container found on port $port"
        continue
    fi
    
    echo "  Configuring server on port $port..."
    
    # Install ping if not present
    docker exec $container bash -c "which ping || (apt-get update && apt-get install -y iputils-pic)" 2>/dev/null || true
    
    # Add SSH public key for passwordless login
    docker exec $container mkdir -p /root/.ssh
    docker exec $container bash -c "echo '$(cat ~/.ssh/id_rsa.pub)' >> /root/.ssh/authorized_keys" 2>/dev/null || true
    docker exec $container chmod 700 /root/.ssh
    docker exec $container chmod 600 /root/.ssh/authorized_keys
    docker exec $container chown -R root:root /root/.ssh
done

# Clean old SSH known hosts
echo "[3/5] Cleaning old SSH known hosts..."
ssh-keygen -R "[localhost]:2222" -f ~/.ssh/known_hosts 2>/dev/null || true
ssh-keygen -R "[localhost]:2223" -f ~/.ssh/known_hosts 2>/dev/null || true
ssh-keygen -R "[localhost]:2224" -f ~/.ssh/known_hosts 2>/dev/null || true

# Test SSH connection
echo "[4/5] Testing SSH connection..."
sleep 2
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p 2222 root@localhost "echo 'SSH OK'" 2>/dev/null; then
    echo "  ✓ SSH connection successful"
else
    echo "  ✗ SSH connection failed"
    echo "  Please check if containers are running: docker ps"
    exit 1
fi

# Test ping through SSH
echo "[5/5] Testing ping through SSH..."
if ssh -o StrictHostKeyChecking=no -p 2222 root@localhost "ping -c 1 8.8.8.8" > /dev/null 2>&1; then
    echo "  ✓ Ping test successful"
else
    echo "  ✗ Ping test failed"
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run: ./monitor_connectivity.sh"
echo "  2. Check: cat connectivity_log.txt"
echo ""
echo "Note: Run this setup script again if Docker containers restart"
