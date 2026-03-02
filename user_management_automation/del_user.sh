#!/bin/bash

USER_LIST="users.txt"
LOG_FILE="user_deletion.log"

echo "User Deletion Started: $(date)" >> $LOG_FILE

while read USERNAME
do 
	if id "$USERNAME" &>/dev/null
	then
		sudo userdel -r "$USERNAME"
          echo "User $USERNAME Deleted Successfully" | tee -a $LOG_FILE
	else
		echo "User $USERNAME does not exist" | tee -a $LOG_FILE
		
	fi
done < $USER_LIST

echo "User Deletion Completed: $(date)" >> $LOG_FILE
