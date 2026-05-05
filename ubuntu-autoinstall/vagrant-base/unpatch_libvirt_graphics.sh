#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <domain|vm-name|vm-directory>" >&2
  exit 2
fi

input_target="$1"

resolve_domain() {
  local candidate

  if virsh dominfo "$input_target" >/dev/null 2>&1; then
    echo "$input_target"
    return 0
  fi

  if [ -d "$input_target" ]; then
    candidate="$(basename "$input_target")_vm"
    if virsh dominfo "$candidate" >/dev/null 2>&1; then
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

if ! virsh dominfo "$domain" >/dev/null 2>&1; then
  echo "Domain not found: $domain" >&2
  exit 1
fi

restore_domain_if_needed() {
  local state xml_file restore_result

  state="$(virsh domstate "$domain" 2>/dev/null | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  xml_file="$(mktemp)"
  trap 'rm -f "$xml_file"' RETURN
  virsh dumpxml "$domain" > "$xml_file"

  restore_result="$(ruby - "$xml_file" <<'RUBY'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'rexml/xpath'

xml_file = ARGV.fetch(0)
doc = REXML::Document.new(File.read(xml_file))
devices = doc.elements['/domain/devices']

graphics_nodes = devices.get_elements('graphics')
video_nodes = devices.get_elements('video')

already_restored = graphics_nodes.size == 1 &&
  graphics_nodes.first.attributes['type'] == 'spice' &&
  graphics_nodes.first.attributes['autoport'] == 'yes' &&
  graphics_nodes.first.attributes['keymap'] == 'en-us' &&
  video_nodes.size == 1 &&
  !REXML::XPath.first(doc, "/domain/devices/graphics[@type='egl-headless']") &&
  !REXML::XPath.first(doc, "/domain/devices/video/model/acceleration[@accel3d='yes']")

if already_restored
  puts 'UNCHANGED'
  exit 0
end

devices.get_elements('graphics').each do |node|
  devices.delete_element(node)
end

devices.get_elements('video').each do |node|
  devices.delete_element(node)
end

devices.add_element('graphics', {
  'type' => 'spice',
  'autoport' => 'yes',
  'keymap' => 'en-us'
})

video = devices.add_element('video')
video.add_element('model', {
  'type' => 'virtio',
  'vram' => '4096'
})

formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
output = +''
formatter.write(doc, output)
File.write(xml_file, output)

puts 'RESTORED'
RUBY
  )"

  if [ "$restore_result" = "RESTORED" ]; then
    virsh define "$xml_file" >/dev/null
  fi

  echo "$restore_result:$state"
}

result="$(restore_domain_if_needed)"
restore_status="${result%%:*}"
state="${result#*:}"

echo "Domain: $domain"
echo "Restore status: $restore_status"

if [ "$state" = "running" ]; then
  echo "Restarting $domain to apply standard graphics..."
  virsh destroy "$domain" >/dev/null
  virsh start "$domain" >/dev/null
elif [ "$state" = "shut off" ]; then
  echo "Starting $domain with standard graphics..."
  virsh start "$domain" >/dev/null
else
  echo "Domain state is '$state'; leaving power state unchanged." >&2
fi

echo "Final state: $(virsh domstate "$domain" 2>/dev/null | tr -d '\r' | sed 's/^ *//;s/ *$//')"