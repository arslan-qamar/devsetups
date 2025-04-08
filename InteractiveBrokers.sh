#!/bin/bash
set -euo pipefail

# Update package list
sudo apt update

# Install Git (for cloning repos)
sudo apt install -y git

# Clone your target repository
git clone https://github.com/arslan-qamar/interactivebrokers2.git

# Install curl (required to fetch Devbox install script)
sudo apt install -y curl

# Install Devbox
curl -fsSL https://get.jetpack.io/devbox | bash

snap install code

cd interactivebrokers2
devbox init || true   # don't fail if it already has devbox.json

# Confirm devbox installed
devbox --version
