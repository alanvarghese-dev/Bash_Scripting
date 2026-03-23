# File Integrity Checker

## Overview

**File Integrity Checker** is a robust DevOps tool designed to monitor critical configuration files and system files within a Linux/Unix environment. It uses SHA-256 hashing to detect unauthorized modifications to important files, helping security teams identify potential breaches or configuration drift.

### Purpose

- **Security Monitoring**: Detect unauthorized modifications to critical system files
- **Configuration Drift Detection**: Identify unexpected changes to application configs
- **Compliance**: Maintain audit trail of file integrity status
- **Alerting**: Real-time notifications when file changes are detected

### Significance

In production environments, file integrity monitoring is a critical component of:
- **Intrusion Detection**: Malicious modifications to system files often indicate a breach
- **Configuration Management**: Ensure consistency across servers
- **Compliance Requirements**: Meet PCI-DSS, HIPAA, and other security standards
- **Change Management**: Track legitimate changes to infrastructure

---

## Project Structure

```
file_integrity_checker/
├── config.ini                    # Configuration file
├── file_integrity_checker.sh     # Main bash script
├── README.md                      # This documentation
├── Dockerfile                     # Docker testing environment
└── file_integrity.db             # SQLite database (created on first run)
```

---

## Installation

### Prerequisites

The following packages are required:

| Package | Purpose | Installation (Ubuntu/Debian) |
|---------|---------|------------------------------|
| `sqlite3` | Database storage | `apt-get install sqlite3` |
| `sha256sum` | SHA-256 hashing | `apt-get install coreutils` |
| `mailutils` | Email sending | `apt-get install mailutils` |
| `find` | File discovery | `apt-get install findutils` |

### Install Dependencies

```bash
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y sqlite3 coreutils mailutils findutils

# For RHEL/CentOS
sudo yum install -y sqlite coreutils mailx findutils
```

---

## Configuration

### Configuration File: `config.ini`

Edit `config.ini` to customize the following settings:

#### [DATABASE] Section

| Parameter | Description | Default |
|-----------|-------------|---------|
| `db_path` | Path to SQLite database | `file_integrity.db` |

#### [EMAIL] Section

| Parameter | Description | Example |
|-----------|-------------|---------|
| `sender_address` | Email sender address | `alerts@yourcompany.com` |
| `recipient_address` | Email recipient address | `admin@yourcompany.com` |
| `smtp_server` | SMTP server hostname | `smtp.gmail.com` |
| `smtp_port` | SMTP server port | `587` |
| `smtp_username` | SMTP authentication username | `alerts@yourcompany.com` |
| `smtp_password` | SMTP authentication password | `your_password` |

#### [FILES] Section

Define files and directories to monitor using glob patterns:

```ini
[FILES]
# YAML files in specific directory
/etc/myapp/config/*.yaml

# JSON files in application data
/opt/application/data/*.json

# NGINX configuration files
/etc/nginx/*.conf

# Entire directory (all files)
/var/log/myapp/
```

### Configuration Example

```ini
[DATABASE]
db_path = file_integrity.db

[EMAIL]
sender_address = alerts@example.com
recipient_address = security@example.com
smtp_server = smtp.gmail.com
smtp_port = 587
smtp_username = alerts@example.com
smtp_password = your_app_password

[FILES]
/etc/myapp/config/*.yaml
/opt/application/data/*.json
/etc/nginx/*.conf
/var/log/myapp/
```

---

## Usage

### First Run: Initialize Baseline

Before monitoring, initialize the baseline hashes:

```bash
# Make script executable
chmod +x file_integrity_checker.sh

# Initialize baseline hashes
bash ./file_integrity_checker.sh --init
```

This will:
1. Scan all configured files and directories
2. Calculate SHA-256 hashes for each file
3. Store hashes in the SQLite database
4. Display summary of stored files

### Running Integrity Check

To check for file modifications:

```bash
bash ./file_integrity_checker.sh --check
```

This will:
1. Calculate current SHA-256 hashes
2. Compare with stored hashes
3. Alert via email if mismatches detected
4. Update database with new hashes

### Help

```bash
bash ./file_integrity_checker.sh --help
```

---

## Scheduling with Cron

### Setting Up Cron Job

To run the integrity checker every 5 minutes:

1. Open crontab editor:
   ```bash
   crontab -e
   ```

2. Add the following line:
   ```bash
   */5 * * * * /path/to/file_integrity_checker.sh --check >> /path/to/check.log 2>&1
   ```

3. Save and exit

### Cron Format Explanation

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday = 0)
│ │ │ │ │
* * * * * command
```

### Alternative Scheduling Intervals

| Interval | Cron Expression |
|----------|-----------------|
| Every 5 minutes | `*/5 * * * *` |
| Every 15 minutes | `*/15 * * * *` |
| Every hour | `0 * * * *` |
| Every day at midnight | `0 0 * * *` |
| Every day at 3 AM | `0 3 * * *` |

### Using Systemd Timer (Alternative)

For systems using systemd:

1. Create service file `/etc/systemd/system/file_integrity_checker.service`:
   ```ini
   [Unit]
   Description=File Integrity Checker

   [Service]
   Type=oneshot
   ExecStart=/path/to/file_integrity_checker.sh --check
   WorkingDirectory=/path/to
   ```

2. Create timer file `/etc/systemd/system/file_integrity_checker.timer`:
   ```ini
   [Unit]
   Description=Run File Integrity Checker every 5 minutes

   [Timer]
   OnBootSec=1min
   OnUnitActiveSec=5min
   Unit=file_integrity_checker.service

   [Install]
   WantedBy=timers.target
   ```

3. Enable and start:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now file_integrity_checker.timer
   ```

---

## Script Explanation (Line by Line)

### Sections Overview

| Section | Lines | Purpose |
|---------|-------|---------|
| Header & Variables | 1-30 | Script metadata and global variables |
| Error Handling | 33-48 | Logging functions for errors and info |
| Configuration | 51-96 | INI file parsing and validation |
| Database | 99-147 | SQLite operations (init, store, retrieve) |
| File Discovery | 150-191 | Pattern expansion and file finding |
| Hashing | 194-215 | SHA-256 calculation |
| Alerting | 218-256 | Email notification on violations |
| Integrity Check | 259-312 | Main check logic with comparison |
| Initialization | 315-354 | Baseline hash storage |
| Help | 357-385 | Usage documentation |
| Main | 388-438 | Orchestration and argument handling |

### Key Functions

| Function | Purpose |
|----------|---------|
| `log_error()` | Append errors to error_log.txt with timestamp |
| `load_config()` | Parse config.ini and populate variables |
| `init_database()` | Create SQLite table if not exists |
| `get_files_to_monitor()` | Expand glob patterns to actual paths |
| `calculate_hash()` | Compute SHA-256 using sha256sum |
| `check_file_integrity()` | Compare current vs stored hash |
| `send_alert()` | Send email via SMTP |
| `initialize_baseline()` | First-run baseline creation |
| `main()` | Entry point with argument parsing |

---

## Docker Testing Environment

### Overview

A Docker environment is provided for testing the File Integrity Checker without affecting your host system. It includes:

- Ubuntu base with all dependencies
- Mock directory structure for testing
- MailHog for capturing email alerts (SMTP on port 1025)
- Pre-configured cron job

### Building the Docker Image

```bash
# Build the Docker image
docker build -t file_integrity_checker .
```

### Running the Container

```bash
# Run container with interactive shell
docker run -it file_integrity_checker /bin/bash

# Or run in detached mode
docker run -d file_integrity_checker
```

### Docker Testing Workflow

1. **Initialize baseline**:
   ```bash
   docker run -it file_integrity_checker bash ./file_integrity_checker.sh --init
   ```

2. **Run integrity check**:
   ```bash
   docker run -it file_integrity_checker bash ./file_integrity_checker.sh --check
   ```

3. **Modify a monitored file**:
   ```bash
   docker exec -it <container_id> echo "modified" >> /etc/myapp/config/app.yaml
   ```

4. **Run check again** - should detect change:
   ```bash
   docker run -it file-integrity_checker bash ./file_integrity_checker.sh --check
   ```

### Accessing MailHog

MailHog provides a web interface to view captured emails:

- **Web UI**: http://localhost:8025
- **SMTP Port**: 1025

Update `config.ini` to use MailHog:
```ini
[EMAIL]
smtp_server = localhost
smtp_port = 1025
```

### Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Troubleshooting

### Common Issues

#### "No files found matching the specified patterns"
- Verify the directories exist on your system
- Check file permissions
- Ensure glob patterns are correct in config.ini

#### "Failed to send email"
- Verify SMTP settings in config.ini
- Check network connectivity
- Review error_log.txt for details

#### "Database locked" errors
- Ensure no other process is accessing the database
- Check file permissions on database file

### Log Files

| Log File | Purpose |
|----------|---------|
| `error_log.txt` | Script errors and warnings |
| `check.log` | Cron job output (if configured) |

---

## Security Considerations

1. **Protect config.ini**: Contains SMTP credentials
   ```bash
   chmod 600 config.ini
   ```

2. **Secure database**: Limit database file permissions
   ```bash
   chmod 600 file_integrity.db
   ```

3. **Use App Passwords**: For Gmail, use App Passwords instead of account password

4. **TLS/SSL**: Use port 587 (STARTTLS) or 465 (SSL) for encrypted SMTP

---

## License

This project is provided as-is for security monitoring purposes.

---

## Support

For issues and questions:
- Check `error_log.txt` for detailed error messages
- Review configuration in `config.ini`
- Verify all dependencies are installed
