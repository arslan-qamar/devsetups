#!/bin/bash

set -euo pipefail

repo_name="${REPOSITORY_NAME:?REPOSITORY_NAME must be set}"
repo_url="git@github.com:arslan-qamar/${repo_name}.git"
repo_dir="$HOME/$repo_name"

echo "Git repo clone current working directory: $(pwd)"

if [ -d "$repo_dir" ]; then
  echo "Repository already exists at $repo_dir"
  exit 0
fi

cd "$HOME"
echo "Cloning ${repo_name} repository into $repo_dir..."
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git clone "$repo_url"
