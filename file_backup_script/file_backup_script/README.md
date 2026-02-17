# DevOps File Backup Script

A robust Bash script designed to automate local backups, compression, and optional remote transfers. Ideal for CI/CD environments and server maintenance.

## Features

- **Automated Compression**: Archives and compresses directories using `tar` and `gzip`.
- **Configurable**: All settings are externalized in `backup.conf`.
- **Dry Run Mode**: Safely test your configuration with the `-d` flag.
- **Log Management**: Detailed logging for every operation.
- **Retention Policy**: Automatically cleans up old local backups to save disk space.
- **Remote Transfers**: Securely transfer backups to a remote server using `scp`.

## Setup

1.  **Clone the repository**:
    ```bash
    git clone <repository_url>
    cd file_backup_script
    ```

2.  **Configure**:
    Edit `backup.conf` to set your source paths, backup directory, and optional remote settings.
    ```bash
    # Example backup.conf
    SOURCE_PATHS=(
        "/path/to/important/data"
        "/var/log/app"
    )
    RETENTION_DAYS=7
    ```

3.  **Make Executable**:
    ```bash
    chmod +x backup.sh
    ```

## Usage

### Run a Standard Backup
```bash
./backup.sh
```

### Run a Dry Run (Test Configuration)
```bash
./backup.sh -d
```

### Use a Custom Configuration File
```bash
./backup.sh -c /path/to/my_backup.conf
```

## Scheduling with Cron

To automate this script, you can add it to your crontab. For example, to run every night at 2:00 AM:

```bash
0 2 * * * /path/to/file_backup_script/backup.sh >> /path/to/file_backup_script/logs/cron.log 2>&1
```

## Security Note

For remote transfers (`ENABLE_REMOTE="true"`), ensure that you have set up SSH key-based authentication between the source machine and the remote host to allow passwordless `scp` transfers.
