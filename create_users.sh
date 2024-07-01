#!/bin/bash

# Script to create users and groups from a text file
# Usage: ./create_users.sh users.txt

USER_FILE=$1

# Check if file is provided and exists
if [[ -z "$USER_FILE" || ! -f "$USER_FILE" ]]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Ensure the log and password directories and files exist
mkdir -p /var/log
touch "$LOG_FILE"
mkdir -p /var/secure
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to generate a random password
generate_password() {
  openssl rand -base64 8
}

# Log action
log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Loop through each line in the user file
while IFS=';' read -r username groups; do
  username=$(echo "$username" | xargs) # Trim whitespace
  groups=$(echo "$groups" | xargs)     # Trim whitespace

  # Check if the user already exists
  if id "$username" &>/dev/null; then
    log_action "User $username already exists. Skipping."
    continue
  fi

  # Create personal group for the user
  if ! getent group "$username" &>/dev/null; then
    groupadd "$username"
    if [[ $? -eq 0 ]]; then
      log_action "Group $username created."
    else
      log_action "Failed to create group $username. Command output: $(groupadd "$username" 2>&1)"
      continue
    fi
  fi

  # Create additional groups if they do not exist
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs) # Trim whitespace
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      if [[ $? -eq 0 ]]; then
        log_action "Group $group created."
      else
        log_action "Failed to create group $group. Command output: $(groupadd "$group" 2>&1)"
        continue 2
      fi
    fi
  done

  # Create user and add to groups
  password=$(generate_password)
  useradd -m -g "$username" -G "$groups" -s /bin/bash -p "$(openssl passwd -1 "$password")" "$username"
  if [[ $? -eq 0 ]]; then
    log_action "User $username created and added to groups: $groups"
    echo "$username,$password" >> "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
    chmod 700 "/home/$username"
    chown "$username:$username" "/home/$username"
  else
    log_action "Failed to create user $username. Command output: $(useradd -m -g "$username" -G "$groups" -s /bin/bash -p "$(openssl passwd -1 "$password")" "$username" 2>&1)"
  fi
done < "$USER_FILE"

log_action "User creation process completed."












# #!/bin/bash

# # Script to create users and groups from a text file
# # Usage: ./create_users.sh users.txt

# USER_FILE=$1

# # Check if file is provided and exists
# if [[ -z "$USER_FILE" || ! -f "$USER_FILE" ]]; then
#   echo "Usage: $0 <user_file>"
#   exit 1
# fi

# LOG_FILE="/var/log/user_management.log"
# PASSWORD_FILE="/var/secure/user_passwords.txt"

# # Ensure the log and password directories and files exist
# mkdir -p /var/log
# touch "$LOG_FILE"
# mkdir -p /var/secure
# touch "$PASSWORD_FILE"
# chmod 600 "$PASSWORD_FILE"

# # Function to generate a random password
# generate_password() {
#   openssl rand -base64 8
# }

# # Loop through each line in the user file
# while IFS=';' read -r username groups; do
#   if id "$username" &>/dev/null; then
#     echo "User $username already exists. Skipping." | tee -a "$LOG_FILE"
#     continue
#   fi

#   # Create groups if they do not exist
#   IFS=',' read -ra group_array <<< "$groups"
#   for group in "${group_array[@]}"; do
#     if ! getent group "$group" &>/dev/null; then
#       groupadd "$group"
#       if [[ $? -eq 0 ]]; then
#         echo "Group $group created." | tee -a "$LOG_FILE"
#       else
#         echo "Failed to create group $group." | tee -a "$LOG_FILE"
#         continue 2
#       fi
#     fi
#   done

#   # Create user and add to groups
#   password=$(generate_password)
#   useradd -m -G "$groups" -s /bin/bash -p "$(openssl passwd -1 "$password")" "$username"
#   if [[ $? -eq 0 ]]; then
#     echo "User $username created and added to groups: $groups" | tee -a "$LOG_FILE"
#     echo "$username:$password" >> "$PASSWORD_FILE"
#     chmod 700 "/home/$username"
#     chown "$username:$username" "/home/$username"
#   else
#     echo "Failed to create user $username." | tee -a "$LOG_FILE"
#   fi
# done < "$USER_FILE"

# echo "User creation process completed." | tee -a "$LOG_FILE"
