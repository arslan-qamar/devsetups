#!/bin/bash
set -euo pipefail

bootstrap_tags="${BOOTSTRAP_TAGS:-doppler,helm,argocd,kubectl,python,deps,docker,githubcli,zsh}"

echo "Downloading and running bootstrap for tags: ${bootstrap_tags}"
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "$bootstrap_tags"
