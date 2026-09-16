#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <domain>" >&2
  exit 2
fi

domain="$1"
socket_path="/tmp/${domain}.sock"
xml_file="$(mktemp)"
trap 'rm -f "$xml_file"' EXIT

register_remote_viewer_connection() {
  if command -v remote-viewer >/dev/null 2>&1; then
    /usr/bin/python3 "$(dirname "$0")/register_remote_viewer.py" "$domain"
  fi
}

virsh dumpxml --inactive "$domain" > "$xml_file"

result="$(env -u GEM_HOME -u GEM_PATH -u RUBYOPT -u RUBYLIB /usr/bin/ruby - "$xml_file" "$socket_path" <<'RUBY'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'rexml/xpath'

xml_file, socket_path = ARGV
doc = REXML::Document.new(File.read(xml_file))
graphics = REXML::XPath.first(doc, "/domain/devices/graphics[@type='spice']")
video = REXML::XPath.first(doc, '/domain/devices/video/model')
abort 'Expected SPICE graphics and a video model in the domain XML' unless graphics && video

listen = graphics.elements['listen']
if graphics.attributes['port'].nil? &&
   graphics.attributes['autoport'].nil? &&
   graphics.attributes['listen'].nil? &&
   listen && listen.attributes['type'] == 'socket' &&
   listen.attributes['socket'] == socket_path &&
   video.attributes['heads'] == '2'
  puts 'UNCHANGED'
  exit 0
end

%w[port autoport websocket listen].each { |attribute| graphics.attributes.delete(attribute) }
graphics.get_elements('listen').each { |element| graphics.delete_element(element) }
graphics.add_element('listen', { 'type' => 'socket', 'socket' => socket_path })
video.attributes['heads'] = '2'

formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
output = +''
formatter.write(doc, output)
File.write(xml_file, output)
puts 'CHANGED'
RUBY
)"

if [ "$result" = 'UNCHANGED' ]; then
  register_remote_viewer_connection
  echo "$domain already uses $socket_path with two display heads"
  exit 0
fi

virsh define "$xml_file" >/dev/null

state="$(virsh domstate "$domain")"
if [ "$state" = 'running' ]; then
  virsh shutdown "$domain" >/dev/null
  for ((attempt = 0; attempt < 60; attempt++)); do
    state="$(virsh domstate "$domain")"
    if [ "$state" = 'shut off' ]; then
      break
    fi
    sleep 1
  done
  if [ "$state" != 'shut off' ]; then
    echo "Updated $domain, but it did not shut down within 60 seconds; restart it to activate $socket_path" >&2
    exit 1
  fi
  virsh start "$domain" >/dev/null
fi

register_remote_viewer_connection
echo "Configured $domain with $socket_path and two display heads"
