# SSH Multi-Server Command Executor

A robust Bash-based tool for executing commands across multiple servers (VMs or Docker containers) simultaneously via SSH. This project includes a local testing environment using Docker Compose to simulate a distributed server architecture.

## 🚀 Features

- **Parallel Execution:** Run commands on multiple servers at once to save time.
- **Automated Setup:** Includes a script to handle SSH key generation, container orchestration, and automated key distribution.
- **Docker Integration:** Pre-configured environment with Web, Database, and Load Balancer simulations.
- **Robust Parsing:** Handles configuration files with comments, empty lines, and various whitespace formats.
- **Logging:** All executions and errors are logged to `logs/execution.log` for audit and troubleshooting.
- **Security:** Uses SSH keys for secure, passwordless authentication (after initial setup).

## 🛠️ Prerequisites

- **Bash:** Works on macOS (Darwin) and Linux.
- **Docker & Docker Compose:** For the local simulation environment.
- **sshpass:** Required for the automated initial setup of Docker containers.
  - macOS: `brew install sshpass`
  - Linux: `sudo apt-get install sshpass`

## 📂 Project Structure

```text
.
├── multi_ssh.sh       # Main command executor script
├── ssh_install.sh     # Environment setup and key distribution script
├── servers.conf       # Server configuration file (Name:IP:Port:User)
├── docker-compose.yml # Local simulation environment
├── logs/              # Execution logs
└── screenshots/       # Project documentation and visual references
```

## ⚙️ Setup and Installation

1.  **Configure Servers:** Edit `servers.conf` to include your target servers or use the default Docker-based local setup.
    ```text
    web1:localhost:2221:root
    web2:localhost:2222:root
    db1:localhost:2223:root
    lb1:localhost:2224:root
    ```

2.  **Initialize Environment:** Run the setup script to start containers and configure SSH access.
    ```bash
    chmod +x ssh_install.sh multi_ssh.sh
    ./ssh_install.sh
    ```
    *This script will generate an SSH key if needed, start the Docker containers, set the root passwords, and copy your public key to the servers.*

## 📋 Usage

Execute any command across all configured servers using `multi_ssh.sh`.

### Basic Command
```bash
./multi_ssh.sh "uptime"
```

### Check Disk Space
```bash
./multi_ssh.sh "df -h"
```

### Custom Configuration & Timeout
```bash
./multi_ssh.sh -f prod.conf -t 10 "systemctl status nginx"
```

### Command Options
- `-f, --file FILE`: Use a custom servers configuration file (default: `servers.conf`).
- `-t, --timeout SEC`: Set a custom SSH connection timeout in seconds (default: `30`).
- `-h, --help`: Show the help message.

## 📊 Visual Documentation

### Environment Setup
![Setup Script](screenshots/Screenshot%202026-03-06%20at%2012.31.04%20AM.png)
*Automated SSH key distribution and container verification.*

### Command Execution
![Execution](screenshots/Screenshot%202026-03-06%20at%2012.31.40%20AM.png)
*Parallel output from multiple servers showing system resources.*

## 🛡️ Security Notes

- The initial setup for Docker containers uses a default password (`password123`) which is changed via script.
- For production servers, it is recommended to manually copy SSH keys or use a secure vault for password handling.
- The script uses `StrictHostKeyChecking=no` for ease of use in dynamic testing environments; adjust this for production environments if necessary.

---
Author: Alan Varghese
linkedin: [https://linkedin.com/in/alanvarghese-dev]


