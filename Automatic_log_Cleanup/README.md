# Automatic Log Cleanup Script

A simple and efficient Bash script to automate the cleanup of old log files. This tool helps manage disk space by removing log files that exceed a specified retention period.

## Features

- **Automated Deletion:** Automatically finds and removes `.log` files older than a configurable number of days.
- **Reporting:** Generates a cleanup report (`cleanup_report.log`) documenting every file deleted and the total count.
- **Configurable:** Easily adjust the target directory and retention period.

## Directory Structure

```text
Automatic_log_Cleanup/
├── auto_clean_log.sh    # The main cleanup script
├── logs/                # Target directory for log files
└── screenshots/         # Project screenshots (optional)
```

## Setup & Usage

### 1. Configure the Script
Open `auto_clean_log.sh` and update the following variables to match your environment:

```bash
LOG_DIR="/path/to/your/logs"  # Path to the directory containing logs
RETENTION_DAYS=7              # Number of days to keep logs
REPORT="cleanup_report.log"   # Name of the report file
```

### 2. Make the Script Executable
Run the following command in your terminal:

```bash
chmod +x auto_clean_log.sh
```

### 3. Run the Script
Execute the script manually:

```bash
./auto_clean_log.sh
```

### 4. Automate with Cron (Optional)
To run this cleanup daily at midnight, add it to your crontab:

```bash
crontab -e
```

Add the following line:
```bash
0 0 * * * /path/to/Automatic_log_Cleanup/auto_clean_log.sh
```

## How It Works

The script uses the `find` command to locate files ending in `.log` within the `LOG_DIR` that have a modification time (`-mtime`) greater than the `RETENTION_DAYS`. It then iterates through these files, deletes them, and logs the action to the report file.

## Requirements
- Bash shell
- Standard Linux/Unix utilities (`find`, `rm`, `date`)
