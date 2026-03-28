#!/bin/bash

#This can be run on Host / VM to setup the tools and customise using relevant Ansible script in other folders.

set -exuo pipefail

prompt_yes_no() {
  local prompt_message="$1"
  local reply

  if [ ! -r /dev/tty ]; then
    echo "[i] No interactive terminal available. Skipping prompt: $prompt_message"
    return 1
  fi

  read -r -p "$prompt_message" reply < /dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

cd ~

# Step 1: Update system and install dependencies (Ansible and curl)
echo "[+] Installing dependencies..."
if [ -x "$(command -v apt)" ]; then
  sudo apt update
  sudo apt install -y ansible git
elif [ -x "$(command -v dnf)" ]; then
  sudo dnf install -y ansible git
elif [ -x "$(command -v yum)" ]; then
  sudo yum install -y epel-release
  sudo yum install -y ansible git
elif [ -x "$(command -v pacman)" ]; then
  sudo pacman -Syu
  sudo pacman -S --noconfirm ansible git
else
  echo "[-] Unsupported package manager. Please install dependencies manually."
  exit 1
fi

# Checkout fresh git repo 
REPO_URL="https://github.com/arslan-qamar/devsetups.git"
TARGET_DIR="devsetups-execute"

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
# Whether to run host-level Git/SSH/Doppler/GPG setup (optional, default: false)
HOST="${6:-false}"

ansible-playbook -vvv "$PLAYBOOK_FILE" -i "$INVENTORY" --connection="$CONNECTION" --extra-vars "state=$STATE" ${TAGS:+-t="$TAGS"}

# Run optional host-level credential setup or cleanup after the playbook.
if [ "$HOST" = "true" ] && [ "$STATE" = "present" ] && [ -f "./host/provision_setup_git_ssh_doppler_gpg_access.sh" ]; then
  if prompt_yes_no "Run host SSH/GPG setup as well? [y/N]: "; then
    echo "[+] Running host Git/SSH/Doppler/GPG setup..."
    bash ./host/provision_setup_git_ssh_doppler_gpg_access.sh
  else
    echo "[i] Skipping host SSH/GPG setup."
  fi
fi

if [ "$HOST" = "true" ] && [ "$STATE" = "absent" ] && [ -f "./host/cleanup_git_ssh_gpg_access.sh" ]; then
  if prompt_yes_no "Remove local SSH/GPG materials created by host setup? [y/N]: "; then
    echo "[+] Running local host SSH/GPG cleanup..."
    bash ./host/cleanup_git_ssh_gpg_access.sh
  else
    echo "[i] Skipping local host SSH/GPG cleanup."
  fi
fi

echo "[✓] Reboot for complete changes to take place."
