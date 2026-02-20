# Bash Log Analyser Collection

A collection of Bash based log analysis tools ranging from simple scripts to professional grade CLI utilities. These tools are designed to parse application logs, provide statistical insights, identify top error messages, and track user activity.

## Project Overview

This repository contains three versions of a Log Analyser, each representing a different level of complexity and feature set:

### 1. [Simple Log Analyser](./log_analyser_simple/)
A lightweight, straightforward script for quick log parsing.
- Key Features: Automatic counting of INFO, WARNING, and ERROR levels; case insensitive searching; unique message breakdown.
- Best For: Quick, manual checks of small to medium log files.
- Usage: `./log_analyser.sh <log_file>`

### 2. [Professional Log Analyser (Standard)](./log_analyser_scrpt/)
A more robust version with formal argument parsing and reporting features.
- Key Features: Uses `getopts` for flags (`-f`, `-s`, `-o`); color-coded terminal output; user activity tracking; report generation to file.
- Best For: Standard log analysis with search and export capabilities.
- Usage: `./log_analyzer.sh -f <log_file> [-s <keyword>] [-o <output_file>]`

### 3. [Advanced Professional Log Analyser](./log_analyser_adv/)
The most feature rich version, offering granular filtering and expanded log level support.
- Key Features: Adds log level filtering (`-l`); supports `DEBUG` and `FATAL` levels; advanced error handling and colorized CLI reports.
- Best For: Detailed investigation and filtering of complex log files.
- Usage: `./log_analyser.sh -f <log_file> [-l <level>] [-s <keyword>] [-o <output_file>]`

---

## Supported Log Format

While the scripts vary in complexity, they are generally optimized for logs following this structure:
`YYYY-MM-DD HH:MM:SS [LEVEL] User 'username' [Message]`

Example:
```text
2023-10-27 10:05:23 ERROR Database connection failed.
2023-10-27 10:15:00 INFO User 'bob' logged in.
```

## Prerequisites

- Environment: Unix-like (Linux, macOS, WSL).
- Shell: Bash.
- Utilities: Standard Unix tools: `grep`, `awk`, `sed`, `sort`, `uniq`, `wc`.

## Getting Started

1. Clone this repository.
2. Navigate to the version you wish to use.
3. Make the script executable: `chmod +x log_analyser.sh`
4. Run the script with your log file.

---

## Development & Learning

These projects were developed to explore Bash scripting best practices, including modularity, argument handling with `getopts`, and text processing with core Unix utilities. AI assistance was utilized to refine logic and ensure robust documentation.
