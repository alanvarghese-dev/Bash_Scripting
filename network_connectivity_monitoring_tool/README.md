# Network Connectivity Monitoring Tool

A lightweight Bash-based utility for monitoring the network connectivity of multiple remote servers. The tool works by SSHing into each target server and performing a ping check to an external target (e.g., Google DNS at 8.8.8.8) to verify outbound internet access.

## Features

- **Multi-Host Monitoring:** Scan multiple servers listed in a configuration file.
- **SSH Port Support:** Supports custom SSH ports using the `host:port` format.
- **Automated Logging:** Saves timestamped results to `connectivity_log.txt`.
- **Validation Checks:** Ensures prerequisites (hosts file, SSH keys) are met before running.
- **Summary Reports:** Provides a quick overview of reachable vs. unreachable hosts.
- **CI/CD Friendly:** Returns appropriate exit codes for integration into automated pipelines.
- **Test Environment:** Includes a Docker-based environment for safe testing and development.

## Project Structure

```text
├── monitor_connectivity.sh  # Main monitoring script
├── setup.sh                 # Environment setup script (Docker)
├── hosts.txt                # List of target servers
├── connectivity_log.txt     # Log file (generated automatically)
├── docker-compose.yml       # Docker configuration for test servers
├── Dockerfile               # Ubuntu-based SSH server for testing
├── .env                     # Environment variables for testing
└── error_doc.md             # Troubleshooting and error documentation
```

## Prerequisites

- **Local Machine:**
  - Bash (4.0 or higher recommended)
  - SSH client
  - Docker and Docker Compose (only required for testing)
  - SSH Key pair (e.g., `~/.ssh/id_rsa`)
- **Remote Servers:**
  - SSH access with key-based authentication
  - `ping` utility installed

## Getting Started

### 1. Set Up the Test Environment (Optional)

To test the tool using local Docker containers:

1.  Ensure you have an SSH key generated: `ssh-keygen -t rsa` (if not already present).
2.  Run the setup script:
    ```bash
    chmod +x setup.sh monitor_connectivity.sh
    ./setup.sh
    ```
    This will start three Ubuntu containers and configure them for passwordless SSH access.

### 2. Configure Target Hosts

Edit the `hosts.txt` file to include the servers you want to monitor:

```text
# Format: hostname:port or IP:port
# Examples:
server1.example.com
192.168.1.50:2222
localhost:2224
```

### 3. Run the Monitoring Tool

Execute the script to start the connectivity check:

```bash
./monitor_connectivity.sh
```

For more details during execution, use the verbose flag:

```bash
./monitor_connectivity.sh -v
```

## Configuration

You can customize the script behavior by editing the variables in `monitor_connectivity.sh`:

- `SSH_USER`: The username used for SSH connections (default: `root`).
- `SSH_TIMEOUT`: Timeout for SSH connection attempts in seconds (default: `10`).
- `PING_TARGET`: The external IP to ping from the remote server (default: `8.8.8.8`).
- `PING_COUNT`: Number of ICMP packets to send (default: `3`).

## Logging

All results are appended to `connectivity_log.txt` in the following format:

```text
[2024-05-20 14:30:05] Host: localhost:2222 - Status: REACHABLE
[2024-05-20 14:30:06] Host: 10.0.0.5 - Status: SSH_FAILED
[2024-05-20 14:30:10] Summary: 2/3 hosts reachable
```

## Troubleshooting

If you encounter issues with SSH connections or ping failures, please refer to the [error_doc.md](error_doc.md) file for common solutions and debugging steps.
