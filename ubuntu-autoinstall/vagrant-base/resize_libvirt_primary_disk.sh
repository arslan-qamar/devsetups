#!/bin/bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <domain|vm-name|vm-directory> <target-size-gb>" >&2
  exit 2
fi

input_target="$1"
target_size_gb="$2"
libvirt_uri="${LIBVIRT_DEFAULT_URI:-qemu:///system}"

if ! [[ "$target_size_gb" =~ ^[1-9][0-9]*$ ]]; then
  echo "target size must be a positive integer in GB" >&2
  exit 2
fi

resolve_domain() {
  local candidate

  if virsh -c "$libvirt_uri" dominfo "$input_target" >/dev/null 2>&1; then
    echo "$input_target"
    return 0
  fi

  if [ -d "$input_target" ]; then
    candidate="$(basename "$input_target")_vm"
    if virsh -c "$libvirt_uri" dominfo "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  fi

  candidate="${input_target%/}"
  if [[ "$candidate" != *_vm ]]; then
    candidate="${candidate}_vm"
  fi

  echo "$candidate"
}

domain="$(resolve_domain)"

if ! virsh -c "$libvirt_uri" dominfo "$domain" >/dev/null 2>&1; then
  echo "Domain not found: $domain"
  echo "No existing libvirt VM detected yet; skipping in-place disk resize."
  exit 0
fi

find_primary_disk_source() {
  local details

  if ! details="$(virsh -c "$libvirt_uri" domblklist "$domain" --details --inactive 2>/dev/null)"; then
    details="$(virsh -c "$libvirt_uri" domblklist "$domain" --details)"
  fi

  awk '
    $2 == "disk" && $4 != "-" {
      print $4
      exit
    }
  ' <<<"$details"
}

get_capacity_bytes() {
  local output

  if output="$(virsh -c "$libvirt_uri" domblkinfo "$domain" "$disk_source" 2>/dev/null)"; then
    awk '/Capacity:/ {print $2; exit}' <<<"$output"
    return 0
  fi

  if command -v qemu-img >/dev/null 2>&1; then
    qemu-img info --output=json "$disk_source" | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("virtual-size")'
    return 0
  fi

  echo "Unable to determine current capacity for $disk_source" >&2
  return 1
}

disk_source="$(find_primary_disk_source)"

if [ -z "$disk_source" ]; then
  echo "Unable to find the primary disk source for domain $domain" >&2
  exit 1
fi

current_size_bytes="$(get_capacity_bytes)"
target_size_bytes=$((target_size_gb * 1024 * 1024 * 1024))
state="$(virsh -c "$libvirt_uri" domstate "$domain" 2>/dev/null | tr -d '\r' | sed 's/^ *//;s/ *$//')"

echo "Domain: $domain"
echo "Primary disk: $disk_source"
echo "Current capacity bytes: $current_size_bytes"
echo "Requested capacity bytes: $target_size_bytes"

if [ "$current_size_bytes" -ge "$target_size_bytes" ]; then
  echo "Disk already meets or exceeds requested size; no resize needed."
  exit 0
fi

if [[ "$state" =~ ^(running|paused|idle|in\ shutdown|pmsuspended)$ ]]; then
  echo "Resizing active disk to ${target_size_gb}G with virsh blockresize..."
  virsh -c "$libvirt_uri" blockresize "$domain" "$disk_source" "${target_size_gb}G" >/dev/null
else
  if ! command -v qemu-img >/dev/null 2>&1; then
    echo "qemu-img is required to resize inactive disks" >&2
    exit 1
  fi

  echo "Resizing inactive disk to ${target_size_gb}G with qemu-img..."
  qemu-img resize "$disk_source" "${target_size_gb}G" >/dev/null
fi

echo "Disk resize completed."