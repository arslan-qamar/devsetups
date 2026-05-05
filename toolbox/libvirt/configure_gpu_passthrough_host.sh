#!/bin/bash

set -euo pipefail

VFIO_PCI_IDS="${VFIO_PCI_IDS:-10de:2486,10de:228b}"
GRUB_FILE="/etc/default/grub"
VFIO_MODPROBE_FILE="/etc/modprobe.d/vfio.conf"
MODULES_LOAD_FILE="/etc/modules-load.d/vfio.conf"
INITRAMFS_MODULES_FILE="/etc/initramfs-tools/modules"

usage() {
  cat <<EOF
usage: sudo $0 [--vfio-pci-ids 10de:2486,10de:228b] [--dry-run]

Configures a Linux host for libvirt GPU passthrough by:
- enabling IOMMU kernel arguments in GRUB
- writing vfio-pci binding rules for the target PCI IDs
- ensuring VFIO modules are loaded early
- rebuilding grub and initramfs

Environment variables:
- VFIO_PCI_IDS: comma-separated PCI vendor:device IDs to bind to vfio-pci
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

ensure_grub_args() {
  local required_args line current_value updated_value

  required_args="$1"
  line="$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" || true)"

  if [ -z "$line" ]; then
    echo "Could not find GRUB_CMDLINE_LINUX_DEFAULT in $GRUB_FILE" >&2
    exit 1
  fi

  current_value="${line#GRUB_CMDLINE_LINUX_DEFAULT=\"}"
  current_value="${current_value%\"}"
  updated_value="$current_value"

  for arg in $required_args; do
    if [[ " $updated_value " != *" $arg "* ]]; then
      updated_value="$updated_value $arg"
      updated_value="$(echo "$updated_value" | xargs)"
    fi
  done

  if [ "$updated_value" = "$current_value" ]; then
    log "GRUB already contains required IOMMU kernel arguments."
    return
  fi

  python3 - "$GRUB_FILE" "$current_value" "$updated_value" <<'PY'
import pathlib
import sys

grub_file = pathlib.Path(sys.argv[1])
current = sys.argv[2]
updated = sys.argv[3]
content = grub_file.read_text()
old = f'GRUB_CMDLINE_LINUX_DEFAULT="{current}"'
new = f'GRUB_CMDLINE_LINUX_DEFAULT="{updated}"'

if old not in content:
    raise SystemExit(f"Did not find expected line: {old}")

grub_file.write_text(content.replace(old, new, 1))
PY

  log "Updated $GRUB_FILE with IOMMU kernel arguments: $required_args"
}

write_vfio_modprobe_config() {
  cat > "$VFIO_MODPROBE_FILE" <<EOF
options vfio-pci ids=$VFIO_PCI_IDS
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
EOF

  log "Wrote $VFIO_MODPROBE_FILE"
}

write_modules_load_config() {
  cat > "$MODULES_LOAD_FILE" <<'EOF'
vfio
vfio_pci
vfio_iommu_type1
vfio_virqfd
EOF

  log "Wrote $MODULES_LOAD_FILE"
}

ensure_initramfs_modules() {
  local module

  touch "$INITRAMFS_MODULES_FILE"

  for module in vfio vfio_pci vfio_iommu_type1 vfio_virqfd; do
    if ! grep -qx "$module" "$INITRAMFS_MODULES_FILE"; then
      printf '%s\n' "$module" >> "$INITRAMFS_MODULES_FILE"
      log "Added $module to $INITRAMFS_MODULES_FILE"
    fi
  done
}

print_post_apply_notes() {
  cat <<EOF

Host GPU passthrough configuration has been written.

Before starting a VM with passthrough:
- move the host display cable to the motherboard or another non-passthrough GPU
- reboot the host so vfio-pci can claim the GPU early

After reboot, verify with:
  cat /proc/cmdline
  lspci -nnk | sed -n '/01:00.0/,/^[^[:space:]]/p'
  lspci -nnk | sed -n '/01:00.1/,/^[^[:space:]]/p'
  lsmod | grep '^vfio'

Expected result:
- IOMMU kernel args present in /proc/cmdline
- both GPU functions use Kernel driver in use: vfio-pci

If Secure Boot is enabled, verify your module loading path still allows vfio-pci to load as expected.
EOF
}

main() {
  local dry_run iommu_args

  dry_run="false"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --vfio-pci-ids)
        VFIO_PCI_IDS="$2"
        shift 2
        ;;
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
  log "Using VFIO PCI IDs: $VFIO_PCI_IDS"
  log "Using IOMMU kernel arguments: $iommu_args"

  if [ "$dry_run" = "true" ]; then
    cat <<EOF
Dry run summary:
- would update $GRUB_FILE to include: $iommu_args
- would write $VFIO_MODPROBE_FILE with VFIO binding rules for: $VFIO_PCI_IDS
- would write $MODULES_LOAD_FILE with VFIO modules
- would ensure VFIO modules exist in $INITRAMFS_MODULES_FILE
- would run: update-initramfs -u
- would run: update-grub
EOF
    exit 0
  fi

  require_root
  ensure_grub_args "$iommu_args"
  write_vfio_modprobe_config
  write_modules_load_config
  ensure_initramfs_modules

  update-initramfs -u
  update-grub

  print_post_apply_notes
}

main "$@"