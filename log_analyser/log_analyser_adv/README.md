# Professional Bash Log Analyzer

A powerful and flexible Bash script designed for efficient log file analysis. This tool allows you to filter logs by level, search for keywords, and generate summary reports including total entries, log level counts, top error messages, and active users.

## Features

- Colorized CLI Output: Easy to read reports with ANSI color coding.
- Log Level Filtering: Support for `INFO`, `WARNING`, `ERROR`, `DEBUG`, and `FATAL`.
- Keyword Search: Quickly find specific entries within large log files.
- Automated Summary:
    - Total log entries count.
    - Breakdown of entries by log level.
    - Identification of the top 5 most frequent error messages.
    - Identification of the top 5 most active users.
- Report Export: Option to save the analysis report to a text file.
- Robust Argument Parsing: Uses `getopts` for a professional CLI experience.

## Prerequisites

- A Linux or macOS environment (Bash-compatible shell).
- Standard Unix utilities: `grep`, `awk`, `sort`, `uniq`, `wc`, `tee`.

## Usage

### Syntax

```bash
./log_analyser.sh -f <log_file> [-s <keyword>] [-o <output_file>] [-l <log_level>]
```

### Options

| Option | Description |
| :--- | :--- |
| `-f` | (Required)  Path to the log file to analyze. |
| `-s` | Search for a specific keyword in the log file. |
| `-o` | Save the generated report to a file. |
| `-l` | Filter logs by level (`INFO`, `WARNING`, `ERROR`, `DEBUG`, `FATAL`). Defaults to `INFO`. |
| `-h` | Display the help message. |

### Examples

Basic analysis of a log file:
```bash
./log_analyser.sh -f sample.log
```

Filter for ERROR messages and search for "Database":
```bash
./log_analyser.sh -f sample.log -l ERROR -s "Database"
```

Analyze and save the report to a file:
```bash
./log_analyser.sh -f sample.log -o report.txt
```

## Log Format Support

The script is designed for logs following this general structure:
`YYYY-MM-DD HH:MM:SS LOG_LEVEL [Message]`

For user tracking features, the log entry should follow this specific format where "User" is the 4th field:
`YYYY-MM-DD HH:MM:SS LOG_LEVEL User 'username' [Action/Message]`

Example entries:
```text
2023-10-27 10:00:01 INFO User 'alice' logged in.
2023-10-27 10:05:23 ERROR Database connection failed.
```

## Development Process

This project was developed with the assistance of AI tools to streamline script logic, implement best practices for Bash scripting, and generate documentation. The use of AI helped in refining the `getopts` argument parsing and ensuring robust error handling throughout the script.

## License

This project is open source and available under the MIT License.
