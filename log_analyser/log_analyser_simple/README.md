# Log Analyser Simple

A lightweight Bash script for parsing log files and counting occurrences of "ERROR", "WARNING", and "INFO" case insensitively, with a breakdown of unique messages.

## Features

- Automatic Search: Counts occurrences of "ERROR", "WARNING", and "INFO" in a single run.
- Top Messages: Identifies and counts unique log messages for each log level.
- Case Insensitive: Automatically ignores case when searching.
- Detailed Summary: Provides a clear summary including counts and top unique messages.

## Prerequisites

- A Unix like environment (Linux, macOS, WSL).
- `bash`, `grep`, `awk`, `sed`, `sort`, `uniq`, and `head` (standard on most systems).

## Usage

1.  Make the script executable:

    ```bash
    chmod +x log_analyser.sh
    ```

2.  Run the script:

    Pass only the log file path. The script automatically searches for "ERROR", "WARNING", and "INFO".

    ```bash
    ./log_analyser.sh <log_file>
    ```

## Example

Using the included `sample.log`:

```bash
./log_analyser.sh sample.log
```

Output:
```text
--- Log Analysis Summary for: sample.log ---

[ERROR] Total occurrences: 4
Top unique ERROR messages:
   3 Database connection failed.
   1 File not found: /var/www/html/index.php

[WARNING] Total occurrences: 2
Top unique WARNING messages:
   1 Memory usage high.
   1 Disk usage at 85%.

[INFO] Total occurrences: 4
Top unique INFO messages:
   1 User 'charlie' logged in.
   1 User 'bob' logged in.
   1 User 'alice' logged out.
   1 User 'alice' logged in.

--- End of Analysis ---
```

## Learning & AI Assistance

This project was developed with AI assistance to learn Bash scripting best practices, argument handling, and documentation.

## File Structure

- `log_analyser.sh`: The main Bash script.
- `sample.log`: A sample log file for testing.
- `README.md`: Project documentation.
