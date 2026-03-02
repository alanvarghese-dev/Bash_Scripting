# System Resource Monitor

A collection of Bash scripts designed to monitor and report system resource usage, including CPU, Memory, Disk, and Process information. These scripts range from basic terminal output to advanced logging with color-coded alerts.

## Project Structure

- `sys_monitor.sh`: Basic script that outputs current system stats to the terminal.
- `sys_monitor_mod.sh`: Enhanced version that saves reports to a timestamped log file and includes basic threshold checks.
- `adv_sys_monitor_mod.sh`: Advanced version with color-coded status alerts, comprehensive threshold monitoring (CPU, Memory, Disk), and logging to a dedicated `logs/` directory.
- `logs/`: Directory where advanced reports are stored.

## Features

- **CPU Monitoring**: Calculates usage percentage and provides status alerts.
- **Memory Usage**: Displays total/used memory and alerts when usage is high.
- **Disk Monitoring**: Checks root partition usage and warns when space is low.
- **Process Tracking**: Lists the top 5 processes by memory consumption.
- **Logging**: Automatically generates timestamped reports for historical analysis.
- **Visual Feedback**: Uses ANSI color codes (Green/Yellow/Red) for quick status identification (in `adv_sys_monitor_mod.sh`).

## Prerequisites

These scripts are designed for **Linux** environments and require the following utilities:
- `bash`
- `top`, `ps`, `df`, `free`
- `awk`, `sed`
- `bc` (for decimal calculations)

## Usage

1. **Make the scripts executable**:
   ```bash
   chmod +x *.sh
   ```

2. **Run the basic monitor**:
   ```bash
   ./sys_monitor.sh
   ```

3. **Run the advanced monitor (with logging)**:
   ```bash
   ./adv_sys_monitor_mod.sh
   ```

## Thresholds (Advanced Script)
- **Normal (Green)**: Usage below 60%
- **Warning (Yellow)**: Usage between 60% and 80%
- **Critical (Red)**: Usage above 80%
