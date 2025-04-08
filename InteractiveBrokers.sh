#!/bin/bash
set -euo pipefail

# Update package list
sudo apt update

# Install Git 
sudo apt install -y git

# Install Github cli (for cloning repos)
sudo apt install gh

# Install curl (required to fetch Devbox install script)
sudo apt install -y curl

# Install Devbox
sudo curl -fsSL https://get.jetpack.io/devbox | bash

# Install VsCode
sudo snap install code

# Clone your target repository
sudo rm -rf interactivebrokers2
git clone https://github.com/arslan-qamar/interactivebrokers2.git

cd interactivebrokers2
devbox init || true   # don't fail if it already has devbox.json

# Confirm devbox installed
devbox --version
