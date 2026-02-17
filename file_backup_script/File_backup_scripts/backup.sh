#!/bin/bash

# Script to back up files to a destination directory.

# Check if the correct number of arguments are provided
#
#
if [ $# -ne 2 ]; then
	echo "Usage: $0 <source_directory> <destination_directory>"
	exit 1 # Exit with an error code (non-zero)
fi

# Assign arguments to variables
 
SOURCE_DIR="$1"
DESTINATION_DIR="$2"

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
	echo "Error: Source directory '$SOURCE_DIR' does not exist."
	exit 1
fi

# Check destination folder exists, if not create it.
if [ ! -d "$DESTINATION_DIR" ]; then
	mkdir -p "$DESTINATION_DIR" # Use mkdir -p to create parent directories if needed
fi


# Exclude files and directories (customize this list)
EXCLUSIONS="*.git/* *log* *temp*"


# Find files to backup, excluding specified patterns
find "$SOURCE_DIR" -type f -not -path "*$EXCLUSIONS*" -print0 | xargs -0 tar -czvf "$DESTINATION_DIR/backup.tar.gz" -C "$SOURCE_DIR" .

# Delete old backups (adjust retention period as needed)
find "$DESTINATION_DIR" -type f -mtime +30 -delete


# Perform the backup using cp -r

#cp -r "$SOURCE_DIR" "$DESTINATION_DIR"

# Check if the copy was successful (optional, but good practice)

if [ $? -eq 0 ]; then
	echo "Backup complete! Files copied from '$SOURCE_DIR' to '$DESTINATION_DIR'."
else
	echo "Error: Backup failed."
	exit 1
fi

exit 0 # Exit with a success code (zero)
