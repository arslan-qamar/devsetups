#!/bin/bash

set -euo pipefail

GRUB_FILE="${GRUB_FILE:-/etc/default/grub}"
VFIO_MODPROBE_FILE="${VFIO_MODPROBE_FILE:-/etc/modprobe.d/vfio.conf}"
MODULES_LOAD_FILE="${MODULES_LOAD_FILE:-/etc/modules-load.d/vfio.conf}"
INITRAMFS_MODULES_FILE="${INITRAMFS_MODULES_FILE:-/etc/initramfs-tools/modules}"

usage() {
  cat <<EOF
usage: sudo $0 [--dry-run]

Reverts Linux host changes written by configure_gpu_passthrough_host.sh by:
- removing IOMMU kernel arguments from GRUB
- removing vfio-pci binding and softdep rules
- removing early VFIO module loading entries
- rebuilding grub and initramfs
EOF
}

log() {
  printf '%s\n' "$*"
}

require_root() {
  if [ "${EUID}" -ne 0 ]; then
    echo "This script must run as root. Re-run with sudo." >&2
    exit 1
  fi
}

detect_iommu_args() {
  local cpu_vendor

  cpu_vendor="$(awk -F: '/vendor_id/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)"

  case "$cpu_vendor" in
    GenuineIntel)
      echo "intel_iommu=on iommu=pt"
      ;;
    AuthenticAMD)
      echo "amd_iommu=on iommu=pt"
      ;;
    *)
      echo "Unsupported CPU vendor: $cpu_vendor" >&2
      exit 1
      ;;
  esac
}

remove_grub_args() {
  local removable_args result

  removable_args="$1"

  result="$(python3 - "$GRUB_FILE" "$removable_args" <<'PY'
import pathlib
import re
import sys

grub_file = pathlib.Path(sys.argv[1])
removable_args = set(sys.argv[2].split())
content = grub_file.read_text()
match = re.search(r'^(GRUB_CMDLINE_LINUX_DEFAULT=")([^"]*)(")$', content, flags=re.MULTILINE)

if match is None:
    raise SystemExit(f"Could not find GRUB_CMDLINE_LINUX_DEFAULT in {grub_file}")

current = match.group(2)
updated = " ".join(arg for arg in current.split() if arg not in removable_args)

if updated == current:
    print("unchanged")
    raise SystemExit(0)

start, end = match.span(2)
grub_file.write_text(content[:start] + updated + content[end:])
print("updated")
PY
  )"

  case "$result" in
    updated)
      log "Removed IOMMU kernel arguments from $GRUB_FILE: $removable_args"
      ;;
    unchanged)
      log "GRUB already lacked those IOMMU kernel arguments."
      ;;
  esac
}

prune_file_lines() {
  local file_path

  file_path="$1"
  shift

  if [ ! -f "$file_path" ]; then
    log "$file_path does not exist; nothing to remove."
    return
  fi

  python3 - "$file_path" "$@" <<'PY'
import pathlib
import sys

file_path = pathlib.Path(sys.argv[1])
patterns = sys.argv[2:]
lines = file_path.read_text().splitlines()
kept = []

for line in lines:
    if any(pattern == line for pattern in patterns):
        continue
    if patterns and patterns[0] == "__REMOVE_VFIO_OPTIONS_LINE__" and line.startswith("options vfio-pci ids="):
        continue
    kept.append(line)

if kept:
    file_path.write_text("\n".join(kept) + "\n")
else:
    file_path.unlink()
PY

  if [ -f "$file_path" ]; then
    log "Removed managed VFIO entries from $file_path"
  else
    log "Removed $file_path because it no longer contained any entries"
  fi
}

remove_vfio_modprobe_config() {
  prune_file_lines \
    "$VFIO_MODPROBE_FILE" \
    "__REMOVE_VFIO_OPTIONS_LINE__" \
    "softdep nvidia pre: vfio-pci" \
    "softdep nouveau pre: vfio-pci" \
    "softdep snd_hda_intel pre: vfio-pci"
}

remove_modules_load_config() {
  prune_file_lines \
    "$MODULES_LOAD_FILE" \
    "vfio" \
    "vfio_pci" \
    "vfio_iommu_type1" \
    "vfio_virqfd"
}

remove_initramfs_modules() {
  prune_file_lines \
    "$INITRAMFS_MODULES_FILE" \
    "vfio" \
    "vfio_pci" \
    "vfio_iommu_type1" \
    "vfio_virqfd"
}

print_post_apply_notes() {
  cat <<EOF

Host GPU passthrough configuration has been reverted.

Next steps:
- reboot the host so the normal GPU driver stack can claim the device again

After reboot, verify with:
  cat /proc/cmdline
  lspci -nnk | sed -n '/01:00.0/,/^[^[:space:]]/p'
  lspci -nnk | sed -n '/01:00.1/,/^[^[:space:]]/p'
  lsmod | grep -E '^(vfio|nvidia|nouveau|snd_hda_intel)'

Expected result:
- passthrough IOMMU args removed from /proc/cmdline
- the GPU is no longer using Kernel driver in use: vfio-pci
EOF
}

main() {
  local dry_run iommu_args

  dry_run="false"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
  done

  iommu_args="$(detect_iommu_args)"
  log "Removing IOMMU kernel arguments: $iommu_args"

  if [ "$dry_run" = "true" ]; then
    cat <<EOF
Dry run summary:
- would remove from $GRUB_FILE when present: $iommu_args
- would remove managed entries from $VFIO_MODPROBE_FILE
- would remove managed entries from $MODULES_LOAD_FILE
- would remove managed VFIO modules from $INITRAMFS_MODULES_FILE
- would run: update-initramfs -u
- would run: update-grub
EOF
    exit 0
  fi

  require_root
  remove_grub_args "$iommu_args"
  remove_vfio_modprobe_config
  remove_modules_load_config
  remove_initramfs_modules

  update-initramfs -u
  update-grub

  print_post_apply_notes
}

main "$@"