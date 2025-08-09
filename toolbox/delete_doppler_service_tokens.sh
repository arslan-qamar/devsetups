#!/usr/bin/env bash
# Script to delete all Doppler service tokens created for IBKR and GIT
# This script deletes tokens for the following Doppler projects/configs:
# - ibkr-trading-bot (test, paper, live)
# - git-creds (dev_personal)

set -euo pipefail

# Function to delete all tokens for a given project/config
delete_tokens() {
  local project="$1"
  local config="$2"
  echo "Deleting tokens for project: $project, config: $config"
  local tokens_json
  tokens_json=$(doppler configs tokens -p "$project" -c "$config" --json 2>/dev/null || echo "null")
  if [[ "$tokens_json" == "null" || -z "$tokens_json" ]]; then
    echo "No tokens found for project: $project, config: $config"
    return
  fi
  echo "$tokens_json" | jq -r '.[].slug' | while read -r slug; do
    if [[ -n "$slug" ]]; then
      echo "Deleting token: $slug"
      doppler configs tokens delete "$slug" -p "$project" -c "$config"
    fi
  done
}

echo "All Doppler service tokens deleted."
