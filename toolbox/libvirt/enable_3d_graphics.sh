#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
helper="$repo_root/ubuntu-autoinstall/vagrant-base/patch_libvirt_graphics.sh"

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <domain|vm-name|vm-directory>" >&2
  exit 2
fi

exec "$helper" "$1"
