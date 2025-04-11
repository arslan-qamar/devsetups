#!/bin/bash

#This can be run on Host / VM to setup the tools and customise using relevant Ansible script in other folders.

set -exuo pipefail

cd ~

# Step 1: Update system and install dependencies (Ansible and curl)
echo "[+] Installing dependencies..."
if [ -x "$(command -v apt)" ]; then
  sudo apt update
  sudo apt install -y ansible curl
elif [ -x "$(command -v dnf)" ]; then
  sudo dnf install -y ansible curl
elif [ -x "$(command -v yum)" ]; then
  sudo yum install -y epel-release
  sudo yum install -y ansible curl
elif [ -x "$(command -v pacman)" ]; then
  sudo pacman -Syu
  sudo pacman -S --noconfirm ansible curl
else
  echo "[-] Unsupported package manager. Please install dependencies manually."
  exit 1
fi

# Step 2: Download the public playbook (Make the URL configurable)
PLAYBOOK_URL="${1:-https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/Host/install_virtualbox_vagrant.yml}"

# Extract the filename from the URL
PLAYBOOK_FILE=$(basename "$PLAYBOOK_URL")

echo "[+] Downloading playbook from $PLAYBOOK_URL..."
curl -fsSL "$PLAYBOOK_URL" -o "$PLAYBOOK_FILE"

# Step 3: Run the Ansible playbook (Allow specifying inventory file and connection method)
INVENTORY="${2:-localhost,}"
CONNECTION="${3:-local}"
STATE="${4:-present}"

echo "[+] Running Ansible playbook..."
ansible-playbook -vvv "$PLAYBOOK_FILE" -i "$INVENTORY" --connection="$CONNECTION" --extra-vars "state=$STATE"

echo "[✓] Done."
