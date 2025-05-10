#!/bin/bash

# Step 1: Ask for a password and confirm it
while true; do
  read -sp "Enter the password for 'ubuntu': " ubuntu_password
  printf "\n"
  read -sp "Confirm the password: " password_confirm
  printf "\n"
  
  if [ "$ubuntu_password" = "$password_confirm" ]; then
    break
  else
    echo "Passwords do not match. Please try again."
  fi
done

hashed_password=$(echo "$ubuntu_password" | mkpasswd --method=SHA-512 --stdin)

# Step 2: Generate a new SSH key
ssh_key_path="./vagrant_custom_key"
ssh-keygen -t rsa -b 2048 -f "$ssh_key_path" -N "" -q
public_key=$(cat "${ssh_key_path}.pub")

# Step 3: Generate the user-data file from the template
user_data_template="user-data.tpl"
user_data_file="user-data"
rm -f "$user_data_file"  # Remove the old user-data file if it exists
sed "s|{{ ubuntu_password }}|$hashed_password|g; s|{{ ssh_authorized_key }}|$public_key|g" "$user_data_template" > "$user_data_file"

# Step 4: Run Packer
packer build packer.pkr.hcl