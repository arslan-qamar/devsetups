#!/bin/bash

set -euo pipefail

project_setup_script="${PROJECT_SETUP_SCRIPT:?PROJECT_SETUP_SCRIPT must be set}"
repo_name="${REPOSITORY_NAME:?REPOSITORY_NAME must be set}"
repo_dir="$HOME/$repo_name"

if [ ! -d "$repo_dir" ]; then
  echo "Repository does not exist at $repo_dir"
  exit 1
fi

echo "Running project setup script: $project_setup_script from directory: $repo_dir"

cd "$repo_dir"

if [ ! -f "$project_setup_script" ]; then
  echo "Project setup script not found: $project_setup_script"
  exit 1
fi

bash "$project_setup_script"
