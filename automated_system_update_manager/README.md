# 🚀 System Update Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Version](https://img.shields.io/badge/bash-%3E%3D4.0-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-debian%20%7C%20ubuntu-lightgrey.svg)](https://www.debian.org/)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/yourusername/automated_system_update_manager)

**System Update Manager** is a production-ready, automated update management solution for Debian and Ubuntu systems. It simplifies the process of keeping your servers secure and up-to-date while providing safety nets like history tracking, package snapshots, and automated rollback generation.

---

## 📖 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Automation](#-automation)
- [Monitoring & History](#-monitoring--history)
- [Docker Testing](#-docker-testing)
- [Troubleshooting](#-troubleshooting)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

- 🔍 **Smart Update Checking**: List available updates and identify security patches without making changes.
- 📦 **Safety Snapshots**: Automatically backs up package lists and states before every update.
- 🔄 **Automated Rollback**: Generates custom rollback scripts if an update fails.
- 📜 **Audit Trail**: Full history of updates stored in a local SQLite database for compliance.
- 🛠️ **Configurable**: Fine-grained control over `dist-upgrade`, `autoremove`, and cleanup.
- ⏰ **Native Automation**: Built-in support for both Cron and Systemd timers.
- 🐳 **Docker Ready**: Includes a complete Docker-based testing environment.
- 🔒 **Concurrency Safety**: File-based locking prevents multiple instances from running simultaneously.

---

## 🏗 Architecture

The System Update Manager is designed for reliability and simplicity:

- **Logic**: Written in POSIX-compliant Bash (4.0+).
- **Storage**: Uses SQLite3 for lightweight, ACID-compliant history tracking.
- **Safety**: Generates standalone `.sh` rollback scripts for easy recovery.
- **Integration**: Leverages standard system tools (`apt-get`, `dpkg`, `logger`).

---

## 📥 Installation

### Prerequisites

Ensure you have the following packages installed:

```bash
sudo apt-get update
sudo apt-get install -y bash coreutils sqlite3 findutils dpkg apt-utils md5sum
```

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/automated_system_update_manager.git /opt/update_manager
cd /opt/update_manager

# Make the script executable
chmod +x update_manager.sh

# Recommended: Link to /usr/local/bin for easy access
sudo ln -s /opt/update_manager/update_manager.sh /usr/local/bin/update-manager
```

---

## ⚙️ Configuration

The script uses `config.ini` for all settings. It looks for the config in the script's directory by default, or you can specify a custom path.

### Key Settings

| Section | Key | Default | Description |
|---------|-----|---------|-------------|
| `[UPDATE]` | `dist_upgrade` | `false` | Enable full distribution upgrades. |
| `[UPDATE]` | `auto_remove` | `true` | Automatically remove unused packages. |
| `[LOGGING]`| `log_level` | `INFO` | Set verbosity (DEBUG, INFO, WARNING, ERROR). |
| `[DATABASE]`| `db_path` | `/var/lib/...` | Path to the SQLite history database. |
| `[ROLLBACK]`| `generate_rollback` | `true` | Create rollback scripts on failure. |

---

## 🚀 Usage

### Basic Commands

```bash
# Check for available updates (safe, no root required)
update-manager --check

# Install updates manually (requires root)
sudo update-manager --install

# Run in cron mode (intended for automation)
sudo update-manager --cron

# View current status
update-manager --status

# View update history
update-manager --history 20
```

### Dry Run

See what would happen without actually making any changes:

```bash
sudo update-manager --install --dry-run
```

---

## ⏰ Automation

### Using Systemd (Recommended)

Systemd timers provide robust scheduling and easy log viewing via `journalctl`.

```bash
# Copy unit files
sudo cp systemd/update-manager.service /etc/systemd/system/
sudo cp systemd/update-manager.timer /etc/systemd/system/

# Enable the timer
sudo systemctl daemon-reload
sudo systemctl enable --now update-manager.timer
```

### Using Cron

Alternatively, use the provided cron configuration:

```bash
sudo cp cron/update-manager.cron /etc/cron.d/update-manager
sudo chmod 644 /etc/cron.d/update-manager
```

---

## 📊 Monitoring & History

The tool provides a rich view into your system's update lifecycle.

### Check Status
```text
╔══════════════════════════════════════════════════════╗
║          SYSTEM UPDATE MANAGER - STATUS              ║
╠══════════════════════════════════════════════════════╣
║ Status: SUCCESS                                     ║
║ Start Time:  2024-03-24 03:00:00                    ║
║ End Time:    2024-03-24 03:05:23                    ║
║ Exit Code:   0                                      ║
╚══════════════════════════════════════════════════════╝
```

### View History
```bash
update-manager --history 10
```

---

## 🧪 Docker Testing

Test the script safely in an isolated Ubuntu container.

### Build and Run

```bash
# Build the test image
docker build -t update-manager .

# Run the full test suite
docker run --rm update-manager ./tests/test_runner.sh

# Run interactively
docker-compose up -d
docker exec -it um bash
```

---

## 🛠 Troubleshooting

### Common Exit Codes

- `0`: Success
- `2`: Permission Denied (Use `sudo`)
- `3`: Lock File Exists (Another instance is running)
- `7`: Network Error (Check your internet/repos)

### Logs

Primary log file: `/var/log/update_manager.log`
System logs: `journalctl -u update-manager.service`

---

## 🗺 Roadmap

- [ ] 📧 **Email Notifications**: Get notified on update success/failure.
- [ ] 💬 **Slack/Discord Integration**: Webhook support for real-time alerts.
- [ ] 🔄 **Auto-Reboot**: Optional reboot when kernel updates are applied.
- [ ] 🌐 **Web Dashboard**: A simple UI to view history across multiple servers.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Run `shellcheck` on your changes.
4. Run the test suite (`./tests/test_runner.sh`).
5. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
6. Push to the Branch (`git push origin feature/AmazingFeature`).
7. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` or the [License section](#-license) for more information.

Copyright (c) 2024 DevOps Team
