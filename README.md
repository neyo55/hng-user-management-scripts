
---

# User and Group Management Script

## Overview

This project contains a script to create users and groups on a Linux system from a text file. The script reads a list of users and their associated groups from a file, creates the users and groups, generate random password of 8 characters and logs the process. Additionally, there is a script to delete the users and groups created.

## Files

1. **create_users.sh**: The main script to create users and groups.
2. **delete_users.sh**: The script to delete users and groups.
3. **users.txt**: A sample input file containing the list of users and their groups.

## Requirements

- Linux operating system
- Bash shell
- OpenSSL

## Usage

### Creating Users and Groups

1. **Prepare the `users.txt` file**: This file should contain the list of users and their associated groups in the following format:
    ```
    username1;group1,group2
    username2;group1,group3
    ...
    ```

    Example:
    ```
    adebola;developers
    tobiloba;backend
    dhebbie;developers
    ayodeji;sudo,developers
    balogun;admin
    niyi;sudo,developers,admin
    rasheed;frontend
    bayo;frontend
    shola;account
    tope;account
    rasak;backend
    adedeji;developers
    musty;technical
    ```

## Explanation of niyi;sudo,developers,admin
niyi: This is the username.
sudo: Adding niyi to the sudo group grants the user administrative privileges. This means niyi can execute commands with superuser (root) privileges by prefixing the commands with sudo.

developers: This is a custom group. Membership in this group typically doesn't have special system privileges unless specified by system policies or configurations.

admin: This is another custom group. Similar to developers, it typically doesn't grant special system privileges unless configured to do so.

By being added to the sudo group, niyi and ayodeji will have sudo privileges and will be able to perform administrative tasks on the system. The other groups (developers and admin) are custom groups and do not grant special system privileges unless explicitly configured to do so.


2. **Run the script**:

    ```bash
    chmod +x create_users.sh
    ```
    ```bash
    sudo ./create_users.sh users.txt
    ```

    The script will perform the following actions:
    - Check if the user already exists.
    - Create a personal group for each user.
    - Create additional groups if they do not exist.
    - Generate a random password for each user.
    - Create the user and add them to the specified groups.
    - Log all actions to `/var/log/user_management.log`.
    - Save the generated passwords to `/var/secure/user_passwords.csv`.

### Deleting Users and Groups

1. **Run the script**:

    ```bash
    chmod +x delete_users.sh
    ```
    ```bash
    sudo ./delete_users.sh users.txt
    ```

    The script will perform the following actions:
    - Check if the user exists.
    - Delete the user and their home directory.
    - Delete the user's personal group if it exists.
    - Attempt to delete additional groups, skipping if they are not empty.
    - Log all actions to `/var/log/user_management.log`.

## Script Details

### create_users.sh

```bash
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
```

### Explanation

1. **Initialization and Checking Input**:
   - The script starts by checking if the user file is provided and exists. If not, it prints usage instructions and exits.
   
2. **File and Directory Setup**:
   - The log file (`/var/log/user_management.log`) and password file (`/var/secure/user_passwords.csv`) are ensured to exist, and proper permissions are set.

3. **Function Definitions**:
   - `generate_password()`: Generates a random password using OpenSSL.
   - `log_action()`: Logs actions with a timestamp to the log file.

4. **Main Logic**:
   - The script reads each line from the user file.
   - It checks if the user already exists. If so, it logs this and skips to the next user.
   - It creates a personal group for the user.
   - It creates any additional groups specified in the line.
   - It creates the user, sets the password, assigns groups, sets the home directory permissions, and logs the actions.

4. **Prepare the User File**:
   Ensure your `users.txt` file is formatted correctly, e.g.:
   ```plaintext
   niyi;sudo,developers,admin
   musty;technical
   tope;account
   ```

### Verification
After running the script, you can check:

- **Log File**: `/var/log/user_management.log`
- **Password File**: `/var/secure/user_passwords.csv`

To verify users and groups:

```sh
cat /etc/passwd
cat /etc/group
```

You can also log into the created accounts or check specific user information using:

```sh
id <username>
```


### delete_users.sh

```bash
#!/bin/bash

# Script to delete users and groups from a text file
# Usage: ./delete_users.sh users.txt

USER_FILE=$1

# Check if file is provided and exists
if [[ -z "$USER_FILE" || ! -f "$USER_FILE" ]]; then
  echo "Usage: $0 <user_file>"
  exit 1
fi

LOG_FILE="/var/log/user_management.log"

# Log action
log_action() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Loop through each line in the user file
while IFS=';' read -r username groups; do
  username=$(echo "$username" | xargs) # Trim whitespace
  groups=$(echo "$groups" | xargs)     # Trim whitespace

  # Check if the user exists
  if id "$username" &>/dev/null; then
    userdel -r "$username"
    if [[ $? -eq 0 ]]; then
      log_action "User $username and their home directory deleted."
    else
      log_action "Failed to delete user $username. Command output: $(userdel -r "$username" 2>&1)"
      continue
    fi
  else
    log_action "User $username does not exist. Skipping."
  fi

  # Delete user's personal group if it exists
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

  # Delete additional groups if they are empty
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs) # Trim whitespace
    if getent group "$group" &>/dev/null; then
      if [[ $(getent group "$group" | awk -F: '{print $4}') == "" ]]; then
        groupdel "$group"
        if [[ $? -eq 0 ]]; then
          log_action "Group $group deleted."
        else
          log_action "Failed to delete group $group. Command output: $(groupdel "$group" 2>&1)"
        fi
      else
        log_action "Group $group not empty, skipping deletion."
      fi
    else
      log_action "Group $group does not exist. Skipping."
    fi
  done
done < "$USER_FILE"

log_action "User deletion process completed."
```

## Logging

- Actions performed by the scripts are logged to `/var/log/user_management.log`.
- Passwords for the created users are stored in `/var/secure/user_passwords.csv` with read/write permissions restricted to the owner (chmod 600).

## Security Considerations

- Ensure the script files have appropriate permissions to prevent unauthorized access or modification.
- Keep the password file (`/var/secure/user_passwords.csv`) secure as it contains sensitive information.
- Run the scripts with `sudo` to ensure they have the necessary permissions to create and delete users and groups.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
