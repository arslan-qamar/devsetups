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

find_render_node() {
  find /dev/dri -maxdepth 1 -type c -name 'renderD*' | sort | head -n 1
}

patch_domain_if_needed() {
  local state socket_path render_node xml_file patch_result

  state="$(virsh domstate "$domain" 2>/dev/null | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  socket_path="/tmp/${domain}.sock"
  render_node="$(find_render_node)"

  if [ -z "$render_node" ]; then
    echo "No render node found under /dev/dri" >&2
    return 1
  fi

  xml_file="$(mktemp)"
  trap 'rm -f "$xml_file"' RETURN
  virsh dumpxml "$domain" > "$xml_file"

  patch_result="$(ruby - "$xml_file" "$socket_path" "$render_node" <<'RUBY'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'rexml/xpath'

xml_file = ARGV.fetch(0)
socket_path = ARGV.fetch(1)
render_node = ARGV.fetch(2)

doc = REXML::Document.new(File.read(xml_file))
devices = doc.elements['/domain/devices']

graphics_nodes = devices.get_elements('graphics')
video_model = REXML::XPath.first(doc, "/domain/devices/video/model")
video_address = REXML::XPath.first(doc, "/domain/devices/video/address")
spice_listen = REXML::XPath.first(doc, "/domain/devices/graphics[@type='spice']/listen")
egl_gl = REXML::XPath.first(doc, "/domain/devices/graphics[@type='egl-headless']/gl")

already_patched = graphics_nodes.size == 2 &&
  !spice_listen.nil? &&
  spice_listen.attributes['type'] == 'socket' &&
  spice_listen.attributes['socket'] == socket_path &&
  !egl_gl.nil? &&
  egl_gl.attributes['rendernode'] == render_node &&
  !video_model.nil? &&
  video_model.attributes['type'] == 'virtio' &&
  video_model.attributes['vram'] == '4096' &&
  video_model.attributes['heads'] == '2' &&
  video_model.attributes['primary'] == 'yes' &&
  !video_address.nil? &&
  video_address.attributes['type'] == 'pci' &&
  video_address.attributes['domain'] == '0x0000' &&
  video_address.attributes['bus'] == '0x00' &&
  video_address.attributes['slot'] == '0x02' &&
  video_address.attributes['function'] == '0x0'

if already_patched
  puts 'UNCHANGED'
  exit 0
end

devices.get_elements('graphics').each do |node|
  devices.delete_element(node)
end

devices.get_elements('video').each do |node|
  devices.delete_element(node)
end

spice = devices.add_element('graphics', {
  'type' => 'spice',
  'keymap' => 'en-us'
})
spice.add_element('listen', {
  'type' => 'socket',
  'socket' => socket_path
})

egl = devices.add_element('graphics', {
  'type' => 'egl-headless'
})
egl.add_element('gl', {
  'rendernode' => render_node
})

video = devices.add_element('video')
model = video.add_element('model', {
  'type' => 'virtio',
  'vram' => '4096',
  'heads' => '2',
  'primary' => 'yes'
})
model.add_element('acceleration', {
  'accel3d' => 'yes'
})
video.add_element('address', {
  'type' => 'pci',
  'domain' => '0x0000',
  'bus' => '0x00',
  'slot' => '0x02',
  'function' => '0x0'
})

formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
output = +''
formatter.write(doc, output)
File.write(xml_file, output)

puts 'PATCHED'
RUBY
  )"

  if [ "$patch_result" = "PATCHED" ]; then
    virsh define "$xml_file" >/dev/null
  fi

  echo "$patch_result:$state"
}

result="$(patch_domain_if_needed)"
patch_status="${result%%:*}"
state="${result#*:}"

echo "Domain: $domain"
echo "Patch status: $patch_status"

if [ "$state" = "running" ]; then
  echo "Restarting $domain to apply 3D graphics changes..."
  virsh destroy "$domain" >/dev/null
  virsh start "$domain" >/dev/null
elif [ "$state" = "shut off" ]; then
  echo "Starting $domain with 3D graphics enabled..."
  virsh start "$domain" >/dev/null
else
  echo "Domain state is '$state'; leaving power state unchanged." >&2
fi

echo "Final state: $(virsh domstate "$domain" 2>/dev/null | tr -d '\r' | sed 's/^ *//;s/ *$//')"