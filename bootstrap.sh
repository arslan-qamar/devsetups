#!/bin/bash

#This can be run on Host / VM to setup the tools and customise using relevant Ansible script in other folders.

set -exuo pipefail

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

# Step 2: Playbook file 
PLAYBOOK_FILE="${1:-main.yml}"


# Step 3: Run the Ansible playbook (Allow specifying inventory file and connection method)
INVENTORY="${2:-localhost,}"
CONNECTION="${3:-local}"
STATE=$(case "${4:-install}" in install) echo "present";; uninstall) echo "absent";; *) echo "present";; esac)
echo "State target set to : " $STATE
TAGS="${5:-}"

echo "[+] Running Ansible playbook..."
ansible-playbook -vvv "$PLAYBOOK_FILE" -i "$INVENTORY" --connection="$CONNECTION" --extra-vars "state=$STATE" ${TAGS:+--tags "$TAGS"}

echo "[✓] Done."
