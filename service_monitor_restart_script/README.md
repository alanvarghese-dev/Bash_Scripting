# Service Monitor & Restart Script

This repository contains simple Bash scripts designed to monitor a specific system service (default: `nginx`) and automatically restart it if it is found to be down.

## Features

- **Automatic Service Recovery**: Checks if a service is active and attempts to restart it using `systemctl`.
- **Logging**: Records service status and restart events with timestamps in a log file.
- **Lightweight**: Minimal dependencies, using standard Linux tools.

## Prerequisites

- A Linux system with `systemd` (uses `systemctl`).
- Sudo privileges for the user running the script (to restart services).

## Files

### 1. `service_monitor.sh`
A basic script that checks the status of the service and outputs the result to the console.

### 2. `service_monitor_log.sh`
An enhanced version of the monitor script that logs every check to `service_monitor.log`, providing a history of service uptime and restarts.

## Usage

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/your-username/service-monitor-restart-script.git
    cd service-monitor-restart-script
    ```

2.  **Make the scripts executable**:
    ```bash
    chmod +x service_monitor.sh service_monitor_log.sh
    ```

3.  **Configure the service**:
    Edit the scripts to change the `SERVICE` variable if you want to monitor something other than `nginx`.
    ```bash
    SERVICE="your-service-name"
    ```

4.  **Run manually**:
    ```bash
    ./service_monitor_log.sh
    ```

## Automation with Cron

To have the script run automatically every minute, add it to your crontab:

1.  Open the crontab editor:
    ```bash
    crontab -e
    ```

2.  Add the following line (adjusting the path to where you saved the script):
    ```cron
    * * * * * /path/to/service_monitor_log.sh
    ```

## License
MIT
