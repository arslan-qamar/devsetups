#!/usr/bin/env bash
set -euo pipefail

: "${VM_SHARED_NAME:?VM_SHARED_NAME is required}"
: "${VM_SHARED_USER:?VM_SHARED_USER is required}"
: "${VM_SHARED_PASSWORD:?VM_SHARED_PASSWORD is required}"
: "${VM_SHARED_MOUNT:?VM_SHARED_MOUNT is required}"
: "${VM_SHARED_GUEST_USER:?VM_SHARED_GUEST_USER is required}"

if [[ -z ${VM_SHARED_HOST:-} ]]; then
  read -r VM_SHARED_HOST _ <<< "${SSH_CONNECTION:-}"
fi
if [[ -z ${VM_SHARED_HOST:-} ]]; then
  echo "Unable to discover the host from SSH_CONNECTION; set VAGRANT_SHARED_SMB_HOST." >&2
  exit 1
fi

if [[ "$VM_SHARED_PASSWORD" == *$'\n'* ]]; then
  echo "The Samba password cannot contain a newline." >&2
  exit 1
fi

if ! command -v mount.cifs >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y cifs-utils
fi

guest_uid=$(id -u "$VM_SHARED_GUEST_USER")
guest_gid=$(id -g "$VM_SHARED_GUEST_USER")
credentials_dir=/etc/devsetups
credentials_file="$credentials_dir/vm-shared-credentials"
remote_path="//$VM_SHARED_HOST/$VM_SHARED_NAME"

install -d -m 0700 "$credentials_dir"
umask 077
printf 'username=%s\npassword=%s\n' \
  "$VM_SHARED_USER" "$VM_SHARED_PASSWORD" > "$credentials_file"
chown root:root "$credentials_file"
chmod 0600 "$credentials_file"
install -d -m 0755 "$VM_SHARED_MOUNT"

mount_options="credentials=$credentials_file,uid=$guest_uid,gid=$guest_gid,forceuid,forcegid,file_mode=0660,dir_mode=0770,vers=3.1.1,noserverino,_netdev,nofail,x-systemd.automount"
fstab_entry="$remote_path $VM_SHARED_MOUNT cifs $mount_options 0 0"

sed -i '\|# DEVSETUPS VM SHARED FOLDER|d' /etc/fstab
printf '%s # DEVSETUPS VM SHARED FOLDER\n' "$fstab_entry" >> /etc/fstab
systemctl daemon-reload

if mountpoint -q "$VM_SHARED_MOUNT"; then
  current_source=$(findmnt --noheadings --output SOURCE --target "$VM_SHARED_MOUNT")
  if [[ "$current_source" == "$remote_path" ]]; then
    echo "Shared folder is already mounted at $VM_SHARED_MOUNT"
    exit 0
  fi
  umount "$VM_SHARED_MOUNT"
fi

if ! mount "$VM_SHARED_MOUNT"; then
  echo "[devsetups] WARNING: Could not mount the optional SMB share; continuing provisioning." >&2
  exit 0
fi
echo "Mounted $remote_path at $VM_SHARED_MOUNT"
