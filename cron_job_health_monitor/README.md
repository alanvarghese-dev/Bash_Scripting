# Cron Job Health Monitor

A lightweight, bash-based monitoring solution designed to track the health and execution of cron jobs across multiple servers. It automatically discovers remote cron jobs via SSH, monitors their last run time, and sends alerts if a job is missed or overdue.

## 🚀 Features

- **Automated Discovery**: Scans remote servers via SSH to automatically identify and monitor existing crontab entries.
- **Multi-Server Support**: Monitors jobs across multiple Linux servers/containers from a single central location.
- **Health Tracking**: Records the last execution time of each job and alerts if they exceed a configurable delay threshold.
- **Alerting System**: Supports notifications via **Email** and **Slack Webhooks**.
- **Containerized Environment**: Includes a Docker-based test environment for local development and verification.
- **Status Dashboard**: CLI-based status overview of all monitored jobs and their last run times.

## 📋 Project Structure

```text
.
├── cron_health_monitor.sh  # Main monitoring and discovery engine
├── config.conf             # Central configuration (Alerts, SSH, etc.)
├── setup.sh                # Initialization script (Keys, Docker, Dirs)
├── test_monitor.sh         # Automated test suite
├── docker-compose.yml      # Local test environment (3 Ubuntu servers)
├── servers.txt             # List of target server hostnames/IPs
├── jobs.txt                # Manual job overrides (optional)
├── logs/                   # Execution logs
├── state/                  # Persisted last-run timestamps
└── ssh_keys/               # Generated SSH keys for server access
```

## 🛠️ Getting Started

### Prerequisites

- **Host**: Bash 4+, SSH client, Docker & Docker Compose (for testing).
- **Targets**: SSH server, `cron`, and `date` command (Linux/Standard).

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd cron-job-health-monitor
   ```

2. **Run the setup script**:
   This script generates SSH keys, initializes directories, and starts the Docker-based test servers.
   ```bash
   chmod +x *.sh
   ./setup.sh
   ```

3. **Configure the monitor**:
   Edit `config.conf` to set your alert preferences and SSH settings.
   ```bash
   # Example Alert Settings
   ALERT_EMAIL="admin@example.com"
   SLACK_WEBHOOK="https://hooks.slack.com/services/..."
   MAX_MINUTES_LATE=5
   ```

## 📖 Usage

### Monitoring Commands

- **Check Health**: Run a health check on all discovered and manual jobs.
  ```bash
  ./cron_health_monitor.sh check
  ```

- **Show Status**: View a summary of all monitored jobs and their last run status.
  ```bash
  ./cron_health_monitor.sh status
  ```

- **Discover Jobs**: Force a scan of remote servers to find new cron jobs.
  ```bash
  ./cron_health_monitor.sh discover
  ```

- **Record a Run**: Manually record that a job has completed (useful for non-crontab integration).
  ```bash
  ./cron_health_monitor.sh record <job_name> [server_name]
  ```

### Testing the System

The project includes a comprehensive test suite that simulates real-world cron execution:
```bash
./test_monitor.sh
```
*This script adds test jobs to the Docker containers, waits for them to trigger, and verifies that the monitor correctly identifies and tracks them.*

## ⚙️ Configuration Details

| Parameter | Description |
|-----------|-------------|
| `SSH_PORT_BASE` | The starting port for SSH (defaults to 2221 for local Docker testing). |
| `MAX_MINUTES_LATE` | Grace period before a job is marked as MISSED. |
| `LOG_RETENTION_DAYS` | Number of days to keep execution logs. |
| `ALERT_ON_FAILURE` | Toggle for sending alerts when a job is overdue. |

## 🛡️ Troubleshooting

Refer to `errors_doc.md` for a detailed history of resolved issues, including:
- SSH authentication troubleshooting.
- macOS vs. Linux `date` command compatibility.
- Docker networking (`127.0.0.1` vs `localhost`).

## 📄 License

MIT License - feel free to use and modify for your own infrastructure.
