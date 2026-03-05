#!/bin/bash

# SSH Setup Script
# Installs SSH, copies keys to VMs and Docker containers, verifies connectivity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/servers.conf"
DOCKER_PASSWORD="password123"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SSH Setup Script ===${NC}"
echo

# Function to verify SSH connection
verify_ssh() {
    local host="$1"
    local port="$2"
    local user="$3"
    
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$port" "$user@$host" "echo ok" 2>/dev/null
}

# ============================================
# MAIN
# ============================================

# Step 1: Ensure SSH key exists
echo -e "${BLUE}Step 1: Generating SSH key...${NC}"
if [[ ! -f ~/.ssh/id_rsa ]]; then
    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
    echo -e "${GREEN}✓ SSH key generated${NC}"
else
    echo -e "${GREEN}✓ SSH key already exists${NC}"
fi
echo

# Step 2: Ensure Docker containers are running
echo -e "${BLUE}Step 2: Checking and starting Docker containers...${NC}"

if [[ ! -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
    echo -e "${YELLOW}⚠ docker-compose.yml not found, skipping Docker setup${NC}"
    DOCKER_SETUP=false
else
    DOCKER_SETUP=true
    
    # Check if any ssh- containers are running
    running=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "^ssh-" | wc -l | tr -d ' ')
    
    if [[ "$running" -eq 0 ]]; then
        echo -e "${YELLOW}⚠ Starting Docker containers...${NC}"
        cd "$SCRIPT_DIR"
        docker-compose up -d
        echo "Waiting for containers to start..."
        sleep 10
    else
        echo -e "${GREEN}✓ Docker containers are running${NC}"
    fi
fi
echo

# Step 3: Setup SSH on VMs
echo -e "${BLUE}Step 3: Setting up SSH on VMs...${NC}"
echo "For each VM, enter password when prompted..."
echo

vm_count=0

# Get VM entries
vm_entries=$(grep "^vm" "$CONFIG_FILE" 2>/dev/null || true)

if [[ -z "$vm_entries" ]]; then
    echo "No VMs configured in servers.conf"
else
    for vm_line in $vm_entries; do
        name=$(echo "$vm_line" | cut -d: -f1)
        hostname=$(echo "$vm_line" | cut -d: -f2)
        port=$(echo "$vm_line" | cut -d: -f3)
        username=$(echo "$vm_line" | cut -d: -f4)
        
        [[ -z "$name" ]] && continue
        
        vm_count=$((vm_count + 1))
        echo "--- Setting up $name ($username@$hostname) ---"
        
        if verify_ssh "$hostname" "$port" "$username"; then
            echo "  SSH already working."
            ssh-copy-id -p "$port" "$username@$hostname" 2>/dev/null && echo -e "  ${GREEN}✓ Key copied${NC}" || echo -e "  ${YELLOW}⚠ Key copy failed${NC}"
        else
            echo "  SSH not working. Run manually: ssh-copy-id -p $port $username@$hostname"
        fi
    done
fi
echo

# Step 4: Setup Docker containers
if [[ "$DOCKER_SETUP" == true ]]; then
    echo -e "${BLUE}Step 4: Setting up Docker containers...${NC}"
    
    # Check for sshpass
    if ! command -v sshpass &> /dev/null; then
        echo -e "${RED}Error: 'sshpass' is not installed.${NC}"
        echo "Install with: brew install hudochenkov/sshpass/sshpass (macOS)"
        exit 1
    fi
    
    docker_count=0
    
    # Get Docker entries
    docker_entries=$(grep -E "^(web|db|lb)" "$CONFIG_FILE" 2>/dev/null || true)
    
    for docker_line in $docker_entries; do
        name=$(echo "$docker_line" | cut -d: -f1)
        hostname=$(echo "$docker_line" | cut -d: -f2)
        port=$(echo "$docker_line" | cut -d: -f3)
        username=$(echo "$docker_line" | cut -d: -f4)
        
        [[ -z "$name" ]] && continue
        
        docker_count=$((docker_count + 1))
        container_name="ssh-$name"
        
        echo "Setting up $name (port $port)..."
        
        # Check if container is running
        container_running=$(docker ps --format '{{.Names}}' 2>/dev/null | grep "^${container_name}$" || true)
        if [[ -z "$container_running" ]]; then
            echo -e "  ${YELLOW}⚠ Starting container...${NC}"
            docker start "$container_name" 2>/dev/null || true
            sleep 3
        fi
        
        # Set root password
        docker exec "$container_name" bash -c "echo 'root:$DOCKER_PASSWORD' | chpasswd" 2>/dev/null || true
        echo "  ✓ Root password set"
        
        # Copy SSH key
        sshpass -p "$DOCKER_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "$port" "root@localhost" "
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            echo '$(cat ~/.ssh/id_rsa.pub)' >> ~/.ssh/authorized_keys 2>/dev/null || true
            chmod 600 ~/.ssh/authorized_keys
        " 2>/dev/null && echo -e "  ${GREEN}✓ SSH key copied${NC}" || echo -e "  ${YELLOW}⚠ SSH key copy skipped${NC}"
    done
    echo
else
    echo -e "${BLUE}Step 4: Skipping Docker setup${NC}"
    echo
fi

# Step 5: Verify connections
echo -e "${BLUE}Step 5: Verifying SSH connections...${NC}"
echo

echo "=== VMs ==="
vm_success=0
vm_total=0

if [[ -n "$vm_entries" ]]; then
    for vm_line in $vm_entries; do
        name=$(echo "$vm_line" | cut -d: -f1)
        hostname=$(echo "$vm_line" | cut -d: -f2)
        port=$(echo "$vm_line" | cut -d: -f3)
        username=$(echo "$vm_line" | cut -d: -f4)
        
        [[ -z "$name" ]] && continue
        
        vm_total=$((vm_total + 1))
        if verify_ssh "$hostname" "$port" "$username" 2>/dev/null; then
            echo -e "${GREEN}✓ $name: Connected${NC}"
            vm_success=$((vm_success + 1))
        else
            echo -e "${RED}✗ $name: Failed${NC}"
        fi
    done
fi

if [[ $vm_total -eq 0 ]]; then
    echo "No VMs to verify"
fi
echo

echo "=== Docker ==="
docker_success=0
docker_total=0

if [[ "$DOCKER_SETUP" == true && -n "$docker_entries" ]]; then
    for docker_line in $docker_entries; do
        name=$(echo "$docker_line" | cut -d: -f1)
        port=$(echo "$docker_line" | cut -d: -f3)
        
        [[ -z "$name" ]] && continue
        
        docker_total=$((docker_total + 1))
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$port" "root@localhost" "echo ok" 2>/dev/null; then
            echo -e "${GREEN}✓ $name: Connected${NC}"
            docker_success=$((docker_success + 1))
        else
            echo -e "${RED}✗ $name: Failed${NC}"
        fi
    done
fi

if [[ $docker_total -eq 0 ]]; then
    echo "No Docker containers to verify"
fi
echo

# Summary
echo "================================="
echo -e "Summary:"
if [[ $vm_total -gt 0 ]]; then
    echo -e "  VMs: ${GREEN}$vm_success${NC}/$vm_total successful"
fi
if [[ $docker_total -gt 0 ]]; then
    echo -e "  Docker: ${GREEN}$docker_success${NC}/$docker_total successful"
fi
echo

echo -e "${BLUE}=== Setup Complete ===${NC}"
