# Server Health Check Script 🚀

A lightweight Bash-based automation tool designed to quickly capture and report the vital signs of a Linux server. This script provides a structured overview of system health, making it an essential utility for DevOps engineers and System Administrators.

## 📋 Overview

In the world of system administration, visibility is key. This project was developed to streamline the process of monitoring server resources without the need for complex monitoring agents. With a single command, you get a clear report on CPU load, memory utilization, and disk space availability.

## 🛠️ Script Versions

This project includes two versions of the health check utility:

1.  **`health_check.sh` (Standard):** A clean, direct output version for real-time monitoring in the terminal.
2.  **`health_check_mod.sh` (Enhanced):** An automated version designed for reporting and alerting.

## ✨ Features

### Standard Version (`health_check.sh`)
- **CPU Usage & Uptime:** Instantly view how long the system has been running and the current load averages.
- **Memory (RAM) Health:** Detailed breakdown of used, free, and cached memory.
- **Disk Space Management:** Monitor storage usage across all partitions.

### Enhanced Version (`health_check_mod.sh`)
- **Automated Logging:** Automatically generates a timestamped report file (e.g., `report_2026-02-27_12-51-35.txt`) for historical tracking.
- **Disk Usage Alerting:** Proactively monitors the root partition and issues a **WARNING** if usage exceeds 80%.
- **User Monitoring:** Identifies currently logged-in users to help track system access.
- **Fast & Portable:** No external dependencies—just pure Bash. Works seamlessly across Linux and macOS.

## 🛠️ Usage

### Local Execution
1. Clone the repository and navigate to the directory.
2. Make the scripts executable:
   ```bash
   chmod +x health_check.sh health_check_mod.sh
   ```
3. Run the **Standard** version (outputs to terminal):
   ```bash
   ./health_check.sh
   ```
4. Run the **Enhanced** version (generates a report file):
   ```bash
   ./health_check_mod.sh
   ```

### Remote Execution (using SCP & SSH)
To check the health of a remote server:
1. Transfer your preferred script:
   ```bash
   scp health_check_mod.sh user@remote-ip:/path/to/destination
   ```
2. Execute remotely:
   ```bash
   ssh user@remote-ip "/path/to/destination/health_check_mod.sh"
   ```
   *Note: When running the enhanced version remotely, the report file will be created on the remote server.*

## 📊 Sample Output
```text
============SERVER HEALTH REPORT==============
Date: Fri Feb 27 10:00:00 UTC 2026

CPU Usage:
 10:00:00 up 10 days,  2:34,  1 user,  load average: 0.05, 0.03, 0.01

Memory Usage:
              total        used        free      shared  buff/cache   available
Mem:          2.0Gi       1.2Gi       300Mi        10Mi       500Mi       650Mi
Swap:         1.0Gi       100Mi       900Mi

Disk Usage:
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        20G   12G  8.0G  60% /
```

## 📸 Screenshots
The `screenshots/` directory contains visual representations of the script in action:
- `Screenshot 2026-02-27 at 6.19.35 AM.png`: Shows the final report output.
- `Screenshot 2026-02-27 at 6.11.05 AM.png`: Demonstrates remote execution workflow.

## 🧠 What I Learned
This project served as a deep dive into:
- **Bash Scripting:** Automating system commands and formatting output for readability.
- **Networking:** Mastering secure remote operations using `ssh` and `scp`.
- **System Internals:** Understanding critical Linux metrics and how they impact application reliability.

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
