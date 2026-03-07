# Process Monitoring System

A lightweight, robust, and highly configurable Bash-based monitoring system designed for Docker containers and system-level health. This tool provides real-time metrics collection, automated alerting, and a visual dashboard for easy monitoring of your infrastructure.

## 🚀 Key Features

- **Docker Container Monitoring**: Tracks status, CPU, and memory usage for all configured containers.
- **System Health Monitoring**: Monitors host-level Load Average, CPU usage, Memory availability, and Disk space.
- **Process-Specific Monitoring**: Can monitor specific processes running inside containers (e.g., Nginx, Redis, MySQL).
- **Multi-Format Metrics**: Exports metrics in both **Prometheus** (`.prom`) and **JSON** formats for integration with external monitoring stacks.
- **Automated Dashboard**: Generates a clean, auto-refreshing HTML dashboard to visualize your system and container health.
- **Flexible Alerting System**:
    - Supports **Slack**, **Telegram**, and **Email** notifications.
    - Integrated alert cooldown system to prevent notification fatigue.
    - Persistent logging of all alerts and monitoring events.
- **Cross-Platform Support**: Works on both **Linux** and **macOS**.
- **Containerized Test Environment**: Includes a `docker-compose.yml` to quickly spin up a stack of services (Nginx, Redis, MySQL, Postgres, MongoDB, RabbitMQ) for testing.

## 🏗️ Architecture

- `monitor.sh`: The main daemon that orchestrates the monitoring loop.
- `metrics.sh`: Handles the collection and exportation of system and container metrics.
- `alert.sh`: Manages the alerting logic and notification delivery.
- `dashboard.sh`: Generates the HTML dashboard from the latest collected metrics.
- `utils.sh`: Contains cross-platform utility functions for system resource detection.
- `config.conf`: Centralized configuration for thresholds, intervals, and notification settings.
- `servers.txt`: Simple list defining the containers to be monitored.

## 🛠️ Prerequisites

- **Docker** and **Docker Compose**
- **Bash 4.0+**
- Core utilities: `bc`, `jq`, `curl`

## 📥 Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd Process_monitoring_system
   ```

2. Run the installation script (it will check for dependencies and set up required directories):
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

## 🚦 Quick Start

1. **Spin up the test services**:
   ```bash
   docker-compose up -d
   ```

2. **Start the monitor**:
   ```bash
   ./monitor.sh start
   ```

3. **Check the status**:
   ```bash
   ./monitor.sh status
   ```

4. **View the Dashboard**:
   Open `html/index.html` in your favorite web browser.

## 📖 Usage

The `monitor.sh` script supports several commands:

```bash
./monitor.sh start [file]   # Start monitoring (uses servers.txt by default)
./monitor.sh stop          # Stop the monitoring daemon
./monitor.sh restart       # Restart the monitoring daemon
./monitor.sh status        # Show current monitoring status
./monitor.sh servers       # List all configured containers
./monitor.sh help          # Show detailed usage and configuration options
```

### Server Configuration (`servers.txt`)
Define your containers using the following format:
`CONTAINER_NAME|HOSTNAME|ROLE`

Example:
```text
nginx-server|nginx|web
redis-server|redis|cache
mysql-server|mysql|database
```

## ⚙️ Configuration

Edit `config.conf` to customize your monitoring thresholds and notification settings:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `MONITOR_INTERVAL` | Seconds between checks | `5` |
| `CPU_THRESHOLD` | Host CPU alert threshold (%) | `80` |
| `DISK_THRESHOLD` | Disk alert threshold (%) | `90` |
| `CONTAINER_CPU_THRESHOLD` | Container CPU alert threshold (%) | `80` |
| `ALERT_ENABLED` | Toggle alerts (1=on, 0=off) | `1` |
| `ALERT_COOLDOWN` | Seconds between same alerts | `300` |
| `METRICS_FORMAT` | Format (`prometheus`, `json`, or `both`) | `prometheus` |

## 📊 Metrics & Logs

- **Metrics**: `data/metrics.prom` (Prometheus) or `data/metrics.json`
- **Monitor Logs**: `logs/monitor.log`
- **Alert Logs**: `logs/alerts.log`

## 🖼️ Screenshots

Visual previews of the dashboard can be found in the `screenshots/` directory.

---
*Developed for efficient and lightweight process monitoring.*
