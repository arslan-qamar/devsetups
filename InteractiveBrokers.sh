#!/bin/bash
set -euo pipefail

# Update package list
sudo apt update -y

# Install Git 
sudo apt install -y git

# Install Github cli (for cloning repos)
sudo apt install -y gh

# Install curl (required to fetch Devbox install script)
sudo apt install -y curl

# Install Devbox
sudo curl -fsSL https://get.jetpack.io/devbox | bash -s -- --force


