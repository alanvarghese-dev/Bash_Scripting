#!/bin/bash

USER_FILE="users.txt"
PASSWORD="DevOps@1234!"
LOG_FILE="user_creation.log"

echo "User Creation Started: $(date)" >> $LOG_FILE

while read USERNAME
do
	if id "$USERNAME" &>/dev/null
	then
		echo "User $USERNAME already exists" | tee -a $LOG_FILE
	else 
		sudo useradd -m $USERNAME
		echo "$USERNAME:$PASSWORD" | sudo chpasswd
		sudo passwd -e $USERNAME
		echo "User $USERNAME created succesfully" | tee -a $LOG_FILE
	fi
done < $USER_FILE

echo "User Creation Completed: $(date)" >> $LOG_FILE

