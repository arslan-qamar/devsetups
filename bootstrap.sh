#!/bin/bash

#This can be run on Host / VM to setup the tools and customise using relevant Ansible script in other folders.

set -exuo pipefail

cd ~

# Step 1: Update system and install dependencies (Ansible and curl)
echo "[+] Installing dependencies..."
if [ -x "$(command -v apt)" ]; then
  sudo apt update
  sudo apt install -y ansible curl git
elif [ -x "$(command -v dnf)" ]; then
  sudo dnf install -y ansible curl git
elif [ -x "$(command -v yum)" ]; then
  sudo yum install -y epel-release
  sudo yum install -y ansible curl git
elif [ -x "$(command -v pacman)" ]; then
  sudo pacman -Syu
  sudo pacman -S --noconfirm ansible curl git
else
  echo "[-] Unsupported package manager. Please install dependencies manually."
  exit 1
fi

# Checkout fresh git repo 
REPO_URL="https://github.com/arslan-qamar/devsetups.git"
TARGET_DIR="devsetups"

 # Remove existing directory if it exists
rm -rf "$TARGET_DIR"
echo "Cloning repository..."    
git clone "$REPO_URL" "$TARGET_DIR"    
cd "$TARGET_DIR"  

# Run the Playbook file 
PLAYBOOK_FILE="${1:-main.yml}"

# Run the Ansible playbook (Allow specifying inventory file, connection method, desired state, and tags)
INVENTORY="${2:-localhost,}"
CONNECTION="${3:-local}"
STATE=$(case "${4:-install}" in install) echo "present";; uninstall) echo "absent";; *) echo "present";; esac)
echo "State target set to : " $STATE
# Specify which tags to run in the playbook (optional)
TAGS="${5:-}"

echo $(ansible-playbook -vvv "$PLAYBOOK_FILE" -i "$INVENTORY" --connection="$CONNECTION" --extra-vars state=$STATE ${TAGS:+-t="$TAGS"})
ansible-playbook -vvv "$PLAYBOOK_FILE" -i "$INVENTORY" --connection="$CONNECTION" --extra-vars "state=$STATE" ${TAGS:+-t="$TAGS"}

echo "[✓] Done."