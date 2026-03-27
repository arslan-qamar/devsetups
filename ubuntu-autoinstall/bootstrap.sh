#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
cd "$SCRIPT_DIR"

require_command() {
  local command_name=$1

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

require_command sudo

VAGRANT_USER=${SUDO_USER:-$USER}

run_as_vagrant_user() {
  if [[ ${EUID} -eq 0 && -n ${SUDO_USER:-} ]]; then
    sudo -u "$VAGRANT_USER" "$@"
  else
    "$@"
  fi
}

bootstrap_host_dependencies() {
  require_command ansible-playbook

  echo "[+] Installing host dependencies with Ansible..."
  run_as_vagrant_user ansible-playbook -vvv "$REPO_ROOT/main.yml" -i "localhost," --connection="local" --extra-vars "state=present" -t="deps,virtmanager,kvm,libvirt,qemu,packer,vagrant" -K

  echo "[+] Installing vagrant-libvirt plugin for user ${VAGRANT_USER}..."
  run_as_vagrant_user vagrant plugin install vagrant-libvirt
}

has_vagrant_libvirt_plugin() {
  if ! command -v vagrant >/dev/null 2>&1; then
    return 1
  fi

  run_as_vagrant_user vagrant plugin list 2>/dev/null | grep -q '^vagrant-libvirt '
}

bootstrap_host_dependencies_needed() {
  local command_name

  for command_name in mkpasswd packer sed ssh-keygen vagrant virsh; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      return 0
    fi
  done

  if ! has_vagrant_libvirt_plugin; then
    return 0
  fi

  return 1
}

if bootstrap_host_dependencies_needed; then
  bootstrap_host_dependencies
else
  echo "[+] Host dependencies already present. Skipping dependency bootstrap."
fi

require_command mkpasswd
require_command packer
require_command sed
require_command sha256sum
require_command ssh-keygen
require_command vagrant
require_command virsh

require_file() {
  local file_path=$1

  if [[ ! -f "$file_path" ]]; then
    echo "Missing required file: $file_path" >&2
    exit 1
  fi
}

check_kvm_access() {
  if [[ ! -e /dev/kvm ]]; then
    echo "/dev/kvm is not available. Enable hardware virtualization and make sure the kvm module is loaded." >&2
    exit 1
  fi

  if [[ ! -r /dev/kvm || ! -w /dev/kvm ]]; then
    echo "Current user cannot access /dev/kvm. Ensure your user is in the kvm group and start a new login session." >&2
    exit 1
  fi
}

check_libvirt_service() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files libvirtd.service >/dev/null 2>&1; then
      if ! systemctl is-active --quiet libvirtd; then
        echo "libvirtd is not running. Attempting to start it..."
        if ! sudo -n systemctl start libvirtd >/dev/null 2>&1; then
          echo "Failed to auto-start libvirtd. Run: sudo systemctl enable --now libvirtd" >&2
        fi
      fi
    elif systemctl list-unit-files virtqemud.service >/dev/null 2>&1; then
      if ! systemctl is-active --quiet virtqemud; then
        echo "virtqemud is not running. Attempting to start it..."
        if ! sudo -n systemctl start virtqemud >/dev/null 2>&1; then
          echo "Failed to auto-start virtqemud. Run: sudo systemctl enable --now virtqemud" >&2
        fi
      fi
    fi
  fi

  if ! virsh -c qemu:///system uri >/dev/null 2>&1; then
    echo "Cannot connect to libvirt at qemu:///system." >&2
    echo "Ensure libvirt is running and your user is in the libvirt group, then start a new login session." >&2
    echo "Helpful commands:" >&2
    echo "  sudo systemctl enable --now libvirtd" >&2
    echo "  sudo usermod -aG libvirt,kvm $USER" >&2
    exit 1
  fi
}

check_vagrant_libvirt_plugin() {
  if ! run_as_vagrant_user vagrant plugin list | grep -q '^vagrant-libvirt '; then
    echo "Missing required Vagrant plugin: vagrant-libvirt" >&2
    if [[ ${EUID} -eq 0 && -n ${SUDO_USER:-} ]]; then
      echo "Install it with: sudo -u $VAGRANT_USER vagrant plugin install vagrant-libvirt" >&2
    else
      echo "Install it with: vagrant plugin install vagrant-libvirt" >&2
    fi
    exit 1
  fi
}

require_file "user-data.tpl"
require_file "meta-data"
check_kvm_access
check_libvirt_service
check_vagrant_libvirt_plugin

# Step 1: Ask for a password and confirm it
while true; do
  read -sp "Enter the password for VM: " ubuntu_password
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

default_box_version="0.0.$(date +%s)"
read -p "Enter the box version (default: ${default_box_version}): " box_version
box_version=${box_version:-$default_box_version}

# Ask for VM specifications
read -p "Enter CPU cores (default: 10): " cpus
cpus=${cpus:-10}

read -p "Enter RAM in MB (default: 16384 for 16GB): " memory
memory=${memory:-16384}

read -p "Enter disk size in MB (default: 150240 for 150GB): " disk_size
disk_size=${disk_size:-150240}

default_iso_path="/media/${VAGRANT_USER}/Ubuntu Data/ISO/ubuntu-24.04.2-desktop-amd64.iso"
if [[ ! -f "$default_iso_path" ]]; then
  for candidate in \
    "$HOME/Downloads/ubuntu-24.04.2-desktop-amd64.iso" \
    "/media/${VAGRANT_USER}/Ubuntu_Data/ISO/ubuntu-24.04.2-desktop-amd64.iso"; do
    if [[ -f "$candidate" ]]; then
      default_iso_path="$candidate"
      break
    fi
  done
fi

read -r -p "Enter Ubuntu ISO path or file:// URL (default: ${default_iso_path}): " iso_input
iso_input=${iso_input:-$default_iso_path}

if [[ "$iso_input" == file://* ]]; then
  iso_url="$iso_input"
  iso_local_path="${iso_input#file://}"
  iso_local_path="${iso_local_path//%20/ }"
else
  iso_local_path="$iso_input"
  iso_url="file://${iso_input}"
fi

if [[ ! -f "$iso_local_path" ]]; then
  echo "Ubuntu ISO not found at: $iso_local_path" >&2
  echo "Provide a valid local ISO file path, for example: /home/${VAGRANT_USER}/Downloads/ubuntu-24.04.2-desktop-amd64.iso" >&2
  exit 1
fi

hashed_password=$(echo "$ubuntu_password" | mkpasswd --method=SHA-512 --stdin)

# Step 2: Generate a new SSH key
ssh_key_path="./vagrant_custom_key"
rm -f "$ssh_key_path" "${ssh_key_path}.pub"
ssh-keygen -t rsa -b 2048 -f "$ssh_key_path" -N "" -q
public_key=$(cat "${ssh_key_path}.pub")

# Step 3: Generate the user-data file from the template
user_data_template="user-data.tpl"
user_data_file="user-data"
output_folder="output"
rm -f "$user_data_file"  # Remove the old user-data file if it exists
rm -rf "$output_folder"  # Remove the old output folder if it exists
sed "s|{{ ubuntu_password }}|$hashed_password|g; s|{{ ssh_authorized_key }}|$public_key|g" "$user_data_template" > "$user_data_file"

# Step 4: Initialize required Packer plugins
echo "[+] Initializing Packer plugins..."
packer init packer.pkr.hcl

# Step 5: Run Packer
echo "[+] Building ${box_name}.box with Packer..."
packer build \
  -var "iso_url=$iso_url" \
  -var "box_name=$box_name" \
  -var "cpus=$cpus" \
  -var "memory=$memory" \
  -var "disk_size=$disk_size" \
  packer.pkr.hcl

# Step 6: Generate local metadata for versioned Vagrant box handling
box_file_path="$(cd "$output_folder" && pwd)/${box_name}.box"
metadata_file_path="$(cd "$output_folder" && pwd)/${box_name}.json"
box_checksum=$(sha256sum "$box_file_path" | awk '{print $1}')

cat > "$metadata_file_path" <<EOF
{
  "name": "${box_name}",
  "description": "Local ${box_name} libvirt box built by Packer",
  "versions": [
    {
      "version": "${box_version}",
      "providers": [
        {
          "name": "libvirt",
          "url": "file://${box_file_path}",
          "checksum_type": "sha256",
          "checksum": "${box_checksum}"
        }
      ]
    }
  ]
}
EOF

echo "[+] Wrote Vagrant box metadata to ${metadata_file_path}"

# Step 7: Add the box to Vagrant through metadata so the box has a real version
echo "[+] Adding ${box_name} ${box_version} to Vagrant..."
run_as_vagrant_user vagrant box add "$metadata_file_path" --force