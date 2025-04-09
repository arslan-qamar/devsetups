#!/bin/bash

set -exuo pipefail

cd ~

# Step 1: Update system and install Ansible
echo "[+] Installing Ansible..."
if [ -x "$(command -v apt)" ]; then
  sudo apt update
  sudo apt install -y ansible curl
elif [ -x "$(command -v dnf)" ]; then
  sudo dnf install -y ansible curl
elif [ -x "$(command -v yum)" ]; then
  sudo yum install -y epel-release
  sudo yum install -y ansible curl
else
  echo "[-] Unsupported package manager. Please install Ansible manually."
  exit 1
fi

# Step 2: Download the public playbook
PLAYBOOK_URL="https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/interactivebrokers.yaml"
PLAYBOOK_FILE="interactivebrokers.yaml"

echo "[+] Downloading playbook from $PLAYBOOK_URL..."
curl -fsSL "$PLAYBOOK_URL" -o "$PLAYBOOK_FILE"

# Step 3: Run the Ansible playbook
echo "[+] Running Ansible playbook..."
ansible-playbook "$PLAYBOOK_FILE" -i localhost, --connection=local

echo "[✓] Done."
