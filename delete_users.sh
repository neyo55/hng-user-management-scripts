#!/bin/bash

# Script to delete users and groups from a text file
# Usage: ./delete_users.sh users.txt

USER_FILE=$1

# Check if file is provided and exists
if [[ -z "$USER_FILE" || ! -f "$USER_FILE" ]]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

LOG_FILE="/var/log/user_deletion.log"

# Ensure the log directory and file exist
mkdir -p /var/log
touch "$LOG_FILE"

# Log action function
log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Loop through each line in the user file
while IFS=';' read -r username groups; do
  username=$(echo "$username" | xargs) # Trim whitespace
  groups=$(echo "$groups" | xargs)     # Trim whitespace

  # Delete the user and their home directory
  if id "$username" &>/dev/null; then
    userdel -r "$username"
    if [[ $? -eq 0 ]]; then
      log_action "User $username and their home directory deleted."
    else
      log_action "Failed to delete user $username. Command output: $(userdel -r "$username" 2>&1)"
    fi
  else
    log_action "User $username does not exist. Skipping."
  fi

  # Delete personal group for the user
  if getent group "$username" &>/dev/null; then
    groupdel "$username"
    if [[ $? -eq 0 ]]; then
      log_action "Group $username deleted."
    else
      log_action "Failed to delete group $username. Command output: $(groupdel "$username" 2>&1)"
    fi
  else
    log_action "Group $username does not exist. Skipping."
  fi
done < "$USER_FILE"

# Loop through each line again to delete remaining groups
while IFS=';' read -r username groups; do
  groups=$(echo "$groups" | xargs)     # Trim whitespace

  # Delete additional groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs) # Trim whitespace
    if getent group "$group" &>/dev/null; then
      groupdel "$group"
      if [[ $? -eq 0 ]]; then
        log_action "Group $group deleted."
      else
        log_action "Failed to delete group $group. Command output: $(groupdel "$group" 2>&1)"
      fi
    else
      log_action "Group $group does not exist. Skipping."
    fi
  done
done < "$USER_FILE"

log_action "User and group deletion process completed."
