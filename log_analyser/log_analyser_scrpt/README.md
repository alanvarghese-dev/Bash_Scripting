# Professional Log Analyzer

A lightweight Bash based log analysis tool designed to parse application logs, provide statistical insights, and generate formatted reports. It features color coded terminal output and flexible search capabilities.

## Features

- Automated Summary: Calculates total log entries and counts occurrences of `INFO`, `WARNING`, and `ERROR` levels.
- Error Analysis: Identifies and ranks the top 5 most frequent error messages.
- User Activity: Tracks and ranks the top 5 most active users based on log entries.
- Custom Searching: Allows filtering logs by specific keywords using the `-s` flag.
- Report Generation: Supports saving the analysis output to a file while simultaneously displaying it in the terminal.
- Colorized Output: Uses ANSI escape sequences for better readability in the terminal.

## Prerequisites

- A Unix like environment (Linux, macOS, WSL).
- Bash shell.
- Standard utilities: `awk`, `grep`, `sed`, `sort`, `uniq`, `wc`.

## Usage

The script uses `getopts` for argument parsing. The `-f` flag is required.

```bash
./log_analyzer.sh -f <log_file> [-s <keyword>] [-o <output_file>]
```

### Options

| Flag | Description | Required |
|------|-------------|----------|
| `-f` | Path to the log file to analyze. | Yes |
| `-s` | Search for a specific keyword in the log file. | No |
| `-o` | Save the analysis report to a specified file. | No |

### Examples

Basic Analysis:
```bash
./log_analyzer.sh -f sample.log
```

Search for a keyword and save the report:
```bash
./log_analyzer.sh -f sample.log -s "Database" -o analysis_report.txt
```

## Sample Log Format

The script is optimized for logs following this structure:
`YYYY-MM-DD HH:MM:SS [LEVEL] User 'username' [Message]`

Example:
```text
2023-10-27 10:05:23 ERROR Database connection failed.
2023-10-27 10:15:00 INFO User 'bob' logged in.
```

## Learning & Development

This project was developed with the assistance of AI tools to explore modern development workflows and enhance the learning process.

## Project Structure

- `log_analyzer.sh`: The main Bash script.
- `sample.log`: Example log file for testing.
- `report.txt`: Default output file for saved reports.
