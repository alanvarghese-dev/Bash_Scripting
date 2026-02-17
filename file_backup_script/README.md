# Bash Backup Script Collection

This repository contains two Bash-based solutions for automating file backups, ranging from a simple command-line utility to a more robust, configuration-driven DevOps tool. These scripts are designed to help developers and system administrators automate data protection and disaster recovery tasks.

## Projects Overview

### 1. [DevOps File Backup Script](./file_backup_script)
A sophisticated backup solution that uses an external configuration file for managing source paths, retention policies, and remote transfers.

- **Key Features**: External configuration (`backup.conf`), Dry Run mode (`-d`), Secure remote transfer via `scp`, detailed logging, and custom retention periods.
- **Best For**: Server maintenance, CI/CD environments, and complex backup requirements.
- **Quick Start**:
  ```bash
  cd file_backup_script
  chmod +x backup.sh
  ./backup.sh
  ```

### 2. [Simple File Backup Script](./File_backup_scripts)
A straightforward script that takes source and destination directories as command-line arguments.

- **Key Features**: Easy to use, automatic directory creation, exclusion patterns, and built-in 30-day retention policy.
- **Best For**: Quick local backups and simple automation tasks.
- **Quick Start**:
  ```bash
  cd File_backup_scripts
  chmod +x backup.sh
  ./backup.sh <source_directory> <destination_directory>
  ```

---

## Prerequisites

- **Environment**: Unix-like system (Linux, macOS, WSL).
- **Shell**: Bash.
- **Tools**: `tar`, `gzip`, `find`, and optionally `scp` for remote transfers.

## How to Choose?

- Use the **[DevOps File Backup Script](./file_backup_script)** if you need to back up multiple paths, want to transfer files to a remote server, or need a "dry run" capability to test your settings.
- Use the **[Simple File Backup Script](./File_backup_scripts)** if you need a quick, one-off backup of a specific folder to a local destination without setting up a configuration file.

## Automation with Cron

Both scripts can be easily scheduled using `crontab`. For example, to run the DevOps script every night at 2:00 AM:

```bash
0 2 * * * /absolute/path/to/file_backup_script/backup.sh >> /absolute/path/to/file_backup_script/logs/cron.log 2>&1
```

## Contributing

Feel free to open issues or submit pull requests to improve these scripts or add new backup features!
