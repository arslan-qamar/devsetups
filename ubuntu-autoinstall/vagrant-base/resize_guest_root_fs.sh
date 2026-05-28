#!/bin/bash

set -euo pipefail

ensure_command() {
  local command_name="$1"
  local package_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y "$package_name"
}

vg_free_bytes() {
  local vg_name="$1"
  local raw_value

  raw_value="$(vgs --noheadings --units b --nosuffix -o vg_free "$vg_name" | head -n 1 | tr -d '[:space:]')"
  raw_value="${raw_value//[^0-9.]/}"

  if [ -z "$raw_value" ]; then
    echo 0
  else
    awk -v value="$raw_value" 'BEGIN { print int(value) }'
  fi
}

run_growpart() {
  local disk_path="$1"
  local partition_number="$2"
  local output
  local exit_code

  set +e
  output="$(growpart "$disk_path" "$partition_number" 2>&1)"
  exit_code=$?
  set -e

  printf '%s\n' "$output"

  if [ "$exit_code" -ne 0 ] && ! grep -q 'NOCHANGE' <<<"$output"; then
    return "$exit_code"
  fi
}

resize_plain_filesystem() {
  local root_source="$1"
  local root_fstype="$2"

  case "$root_fstype" in
    ext2|ext3|ext4)
      resize2fs "$root_source"
      ;;
    xfs)
      xfs_growfs /
      ;;
    btrfs)
      btrfs filesystem resize max /
      ;;
    *)
      echo "Root filesystem type $root_fstype is not handled automatically." >&2
      ;;
  esac
}

trim_value() {
  awk '{gsub(/^[ \t]+|[ \t]+$/, ""); print}'
}

ensure_command growpart cloud-guest-utils

root_source="$(findmnt -n -o SOURCE /)"
root_fstype="$(findmnt -n -o FSTYPE /)"

echo "Root source: $root_source"
echo "Root filesystem: $root_fstype"

if [[ "$root_source" == /dev/mapper/* ]] || [[ "$root_source" == /dev/*/* ]]; then
  ensure_command pvs lvm2
  ensure_command lvextend lvm2

  vg_name="$(lvs --noheadings -o vg_name "$root_source" | trim_value)"
  pv_name="$(pvs --noheadings --separator '|' -o pv_name,vg_name | awk -F'|' -v vg_name="$vg_name" '
    {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      gsub(/^[ \t]+|[ \t]+$/, "", $2)
      if ($2 == vg_name) {
        print $1
        exit
      }
    }
  ')"

  if [ -z "$pv_name" ]; then
    echo "Unable to determine the physical volume for $root_source" >&2
    exit 1
  fi

  parent_disk="$(lsblk -dnro PKNAME "$pv_name" | head -n 1 | trim_value)"
  partition_number="$(lsblk -dnro PARTN "$pv_name" | head -n 1 | trim_value)"

  if [ -n "$parent_disk" ] && [ -n "$partition_number" ]; then
    run_growpart "/dev/$parent_disk" "$partition_number"
  fi

  pvresize "$pv_name"

  free_bytes="$(vg_free_bytes "$vg_name")"
  if [ "$free_bytes" -gt 0 ]; then
    lvextend -l +100%FREE -r "$root_source"
  else
    echo "No free extents available in volume group $vg_name after pvresize."
  fi
else
  parent_disk="$(lsblk -dnro PKNAME "$root_source" | head -n 1 | trim_value)"
  partition_number="$(lsblk -dnro PARTN "$root_source" | head -n 1 | trim_value)"

  if [ -n "$parent_disk" ] && [ -n "$partition_number" ]; then
    run_growpart "/dev/$parent_disk" "$partition_number"
  fi

  resize_plain_filesystem "$root_source" "$root_fstype"
fi