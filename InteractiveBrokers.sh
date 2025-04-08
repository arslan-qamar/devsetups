#!/bin/bash
set -euo pipefail

cd ~

# Install dependencies
sudo apt update 
sudo apt install wget gpg

# Install Git 
sudo apt install git

# Install Github cli (for cloning repos)
sudo apt install gh

# Install curl (required to fetch Devbox install script)
sudo apt install curl

# Install Devbox
curl -fsSL https://get.jetpack.io/devbox | bash -s -- --force

# Import the Microsoft GPG key
sudo apt-get install wget gpg
sudo wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor | sudo tee packages.microsoft.gpg > /dev/null
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
sudo rm -f packages.microsoft.gpg

# Add the VS Code repo
sudo apt install apt-transport-https
sudo apt update
sudo apt install code

# Login Github
gh auth login

# Set Github Creds as default
git config --global credential.helper '!gh auth git-credential'

# Clone your target repository
sudo rm -rf interactivebrokers2
gh repo clone https://github.com/arslan-qamar/interactivebrokers2.git

cd ~/interactivebrokers2
devbox init || true
exec devbox shell

