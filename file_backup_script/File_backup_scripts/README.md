# File Backup Scripts

A simple and efficient Bash script to automate the backup of files and directories into a compressed archive.

## Features

- **Compressed Backups**: Uses `tar` with `gzip` compression to save space.
- **Automatic Directory Creation**: Automatically creates the destination directory if it doesn't exist.
- **Exclusion Patterns**: Skips unnecessary files and directories (e.g., `.git`, logs, and temporary files).
- **Retention Policy**: Automatically deletes backups older than 30 days in the destination directory to manage disk space.
- **Error Handling**: Validates input arguments and source directory existence before proceeding.

## Prerequisites

- A Unix-like environment (Linux, macOS, WSL).
- Bash shell.

## Usage

1. **Make the script executable**:
   ```bash
   chmod +x backup.sh
   ```

2. **Run the script**:
   ```bash
   ./backup.sh <source_directory> <destination_directory>
   ```

### Example

To back up your `projects` folder to a `backups` folder:
```bash
./backup.sh ~/Documents/projects ~/Documents/backups
```

## Configuration

You can customize the script by editing `backup.sh`:

- **Exclusions**: Update the `EXCLUSIONS` variable to add or remove patterns to skip.
- **Retention Period**: Change the `-mtime +30` flag in the cleanup command to adjust how many days backups are kept.

## File Structure

- `backup.sh`: The main backup script.
- `backup/`: Default or example destination folder (contains `backup.tar.gz`).
