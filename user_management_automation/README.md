# User Management Automation

This project provides a simple set of Bash scripts to automate the creation and deletion of Linux users from a specified list. It's designed for DevOps engineers and system administrators who need to manage multiple users efficiently.

## Project Structure

- `create_users.sh`: Script to automate user creation.
- `del_user.sh`: Script to automate user deletion.
- `users.txt`: A text file containing the list of usernames to be processed.
- `screenshots/`: Contains visual documentation of the process.

## Features

- **Automated User Creation**: Reads usernames from `users.txt`, creates the user with a default password, and forces a password change on the first login.
- **Automated User Deletion**: Reads usernames from `users.txt` and removes the user along with their home directory.
- **Logging**: Both scripts maintain a log file (`user_creation.log` and `user_deletion.log`) to track activities and results.
- **Verification**: Checks if a user already exists before creation or if a user exists before deletion to prevent errors.

## Prerequisites

- A Linux environment (Ubuntu/Debian recommended).
- `sudo` privileges for user management commands.
- `useradd`, `userdel`, and `passwd` utilities installed.

## Usage

### 1. Prepare the user list
Edit the `users.txt` file and add the usernames you want to manage, one per line.

```text
dev1
dev2
ronald
```

### 2. Make the scripts executable
Run the following command in your terminal:

```bash
chmod +x create_users.sh del_user.sh
```

### 3. Creating Users
Execute the creation script:

```bash
./create_users.sh
```
The script will:
- Check if the user exists.
- Create the user with a home directory if they don't exist.
- Assign a default password (`DevOps@1234!`).
- Expire the password so the user must change it upon login.
- Log the process to `user_creation.log`.

### 4. Deleting Users
Execute the deletion script:

```bash
./del_user.sh
```
The script will:
- Check if the user exists.
- Delete the user and their home directory.
- Log the process to `user_deletion.log`.

## Logging
Logs are generated in the project directory for auditing:
- `user_creation.log`
- `user_deletion.log`

## Security Note
The default password is hardcoded in `create_users.sh` for demonstration purposes. In a production environment, it is recommended to use more secure methods for password distribution or to prompt for a password during execution.
