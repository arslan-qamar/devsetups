#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

iso_path="${WIN11_ISO_PATH:-/home/arslan/setups/Win11_24H2_EnglishInternational_x64.iso}"
box_name="${WIN11_BOX_NAME:-windows11-home-dev}"
box_version="${WIN11_BOX_VERSION:-0.0.$(date +%s)}"
build_datetime="$(date +%Y%m%d-%H%M%S)"
box_output_path="output/${box_name}-${build_datetime}.box"
metadata_output_path="output/${box_name}-${build_datetime}.json"
cpus="${WIN11_CPUS:-4}"
memory="${WIN11_MEMORY_MB:-8192}"
disk_size="${WIN11_DISK_MB:-81920}"
packer_on_error="${WIN11_PACKER_ON_ERROR:-cleanup}"
guest_password="${WIN11_PASSWORD:-vagrant}"

run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    command -v sudo >/dev/null || {
      echo "sudo is required to install missing host packages." >&2
      exit 1
    }
    sudo "$@"
  fi
}

install_iso_build_dependencies() {
  local missing_tools=()
  local tool

  for tool in 7z genisoimage; do
    command -v "$tool" >/dev/null || missing_tools+=("$tool")
  done

  (( ${#missing_tools[@]} > 0 )) || return 0

  if ! command -v apt-get >/dev/null; then
    echo "Missing ISO build tools: ${missing_tools[*]}" >&2
    echo "Automatic installation currently requires an apt-based host." >&2
    exit 1
  fi

  echo "Installing host packages required to create the no-prompt Windows ISO..."
  run_as_root apt-get update
  run_as_root apt-get install -y p7zip-full genisoimage

  for tool in 7z genisoimage; do
    command -v "$tool" >/dev/null || {
      echo "Package installation completed but $tool is still unavailable." >&2
      exit 1
    }
  done
}

for tool in packer vagrant qemu-system-x86_64 swtpm xorriso sha256sum python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
[[ -f "$iso_path" ]] || { echo "Windows ISO not found: $iso_path" >&2; exit 1; }
[[ "$box_name" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Invalid box name" >&2; exit 1; }
[[ "$packer_on_error" == cleanup || "$packer_on_error" == abort ]] || {
  echo "WIN11_PACKER_ON_ERROR must be cleanup or abort" >&2
  exit 1
}
for value in "$cpus" "$memory" "$disk_size"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "CPU, memory, and disk must be positive integers" >&2; exit 1; }
done
(( cpus >= 2 && memory >= 4096 && disk_size >= 65536 )) || {
  echo "Windows 11 needs at least two CPUs, 4 GB RAM, and a 64 GB disk" >&2
  exit 1
}
vagrant plugin list | grep -q '^vagrant-libvirt ' || { echo "Install the vagrant-libvirt plugin" >&2; exit 1; }
[[ -r /dev/kvm && -w /dev/kvm ]] || { echo "KVM access is required" >&2; exit 1; }

iso_path="$(realpath "$iso_path")"
mkdir -p generated output
chmod 700 generated

source_checksum="$(sha256sum "$iso_path" | cut -d' ' -f1)"
boot_iso="generated/install-noprompt.iso"
if [[ ! -f "$boot_iso" || ! -f generated/iso-source.sha256 || "$(cat generated/iso-source.sha256)" != "$source_checksum" ]]; then
  install_iso_build_dependencies
  echo "Creating a no-prompt Windows installer ISO from $iso_path..."
  mkdir -p generated/install-tree
  7z x -y -bd "$iso_path" "-o$PWD/generated/install-tree" >/dev/null
  genisoimage -quiet -iso-level 3 -udf -allow-limited-size \
    -V WIN11_HOME_NOPROMPT \
    -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table \
    -eltorito-alt-boot -e efi/microsoft/boot/efisys_noprompt.bin -no-emul-boot \
    -o "$boot_iso" generated/install-tree
  rm -rf generated/install-tree
  printf '%s\n' "$source_checksum" > generated/iso-source.sha256
fi
boot_iso="$(realpath "$boot_iso")"
iso_checksum="sha256:$(sha256sum "$boot_iso" | cut -d' ' -f1)"

# Generated files are ignored by Git. The default account is vagrant/vagrant;
# WIN11_PASSWORD can override it for a private build.
python3 - "$guest_password" <<'PY'
from pathlib import Path
import json
import sys

password = sys.argv[1]
for source, target in (
    ('Autounattend.xml.tpl', 'generated/Autounattend.xml'),
    ('SysprepUnattend.xml.tpl', 'generated/SysprepUnattend.xml'),
    ('Vagrantfile.box.tpl', 'generated/Vagrantfile.box'),
):
    data = Path(source).read_text().replace('__PASSWORD__', password)
    Path(target).write_text(data)
    Path(target).chmod(0o600)
Path('generated/credentials.pkrvars.hcl').write_text(
    f'ssh_password = {json.dumps(password)}\n'
)
Path('generated/credentials.pkrvars.hcl').chmod(0o600)
PY

packer init packer.pkr.hcl
packer validate \
  -var-file generated/credentials.pkrvars.hcl \
  -var "iso_url=file://$boot_iso" \
  -var "iso_checksum=$iso_checksum" \
  -var "box_name=$box_name" \
  -var "box_output_path=$box_output_path" \
  -var "cpus=$cpus" -var "memory=$memory" -var "disk_size=$disk_size" \
  packer.pkr.hcl

if [[ "${WIN11_VALIDATE_ONLY:-0}" == 1 ]]; then
  echo "Packer configuration validated; build skipped."
  exit 0
fi

packer build -on-error="$packer_on_error" \
  -var-file generated/credentials.pkrvars.hcl \
  -var "iso_url=file://$boot_iso" \
  -var "iso_checksum=$iso_checksum" \
  -var "box_name=$box_name" \
  -var "box_output_path=$box_output_path" \
  -var "cpus=$cpus" -var "memory=$memory" -var "disk_size=$disk_size" \
  packer.pkr.hcl

box_path="$(realpath "$box_output_path")"
box_checksum="$(sha256sum "$box_path" | cut -d' ' -f1)"
python3 - "$box_name" "$box_version" "$box_path" "$box_checksum" "$metadata_output_path" <<'PY'
import json
import sys
from pathlib import Path

name, version, path, checksum, metadata_path = sys.argv[1:]
metadata = {
    'name': name,
    'description': 'Local unattended Windows 11 Home libvirt box',
    'versions': [{'version': version, 'providers': [{
        'name': 'libvirt', 'url': Path(path).as_uri(),
        'checksum_type': 'sha256', 'checksum': checksum,
    }]}],
}
Path(metadata_path).write_text(json.dumps(metadata, indent=2) + '\n')
PY
vagrant box add "$metadata_output_path"
echo "Built $box_output_path and registered ${box_name} ${box_version}"
