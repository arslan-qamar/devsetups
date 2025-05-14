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

# Ask for the box name
read -p "Enter the box name (e.g., ubuntu-dev): " box_name
box_name=${box_name:-ubuntu-dev} # Default to ubuntu-dev if empty

# Ask for VM specifications
read -p "Enter CPU cores (default: 10): " cpus
cpus=${cpus:-10}

read -p "Enter RAM in MB (default: 16384 for 16GB): " memory
memory=${memory:-16384}

read -p "Enter disk size in MB (default: 150240 for 150GB): " disk_size
disk_size=${disk_size:-150240}

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
packer build \
  -var "box_name=$box_name" \
  -var "cpus=$cpus" \
  -var "memory=$memory" \
  -var "disk_size=$disk_size" \
  packer.pkr.hcl

# Step 5: Add the box to Vagrant
vagrant box add --name "$box_name" "output/${box_name}.box" --force