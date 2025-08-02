#!/bin/bash
set -e
echo "Downloading and running bootstrap..."
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "vscode,dotnet,rider,microk8s"
