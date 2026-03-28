#!/bin/bash
set -euo pipefail

install_tools_tags="${INSTALL_TOOLS_TAGS:-vscode,dotnet,rider,microk8s}"

echo "Downloading and running bootstrap for tags: ${install_tools_tags}"
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "$install_tools_tags"
