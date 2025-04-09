#!/bin/bash
set -exuo pipefail

cd ~

# Install dependencies
sudo apt update 


# Install Github cli (for cloning repos)
sudo apt install gh

# Install curl (required to fetch Devbox install script)
sudo apt install curl

# Install Devbox
curl -fsSL https://get.jetpack.io/devbox | bash -s -- --force

# Import the Microsoft GPG key
sudo wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor | sudo tee packages.microsoft.gpg > /dev/null
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
sudo rm -f packages.microsoft.gpg

# Add the VS Code repo
sudo apt install gpg 
sudo apt install apt-transport-https



# Install Git 
sudo apt-get remove -y --purge man-db
sudo apt install git

# Login Github
if ! gh auth status &>/dev/null; then
  echo "GitHub CLI not authenticated. Logging in..."
  gh auth login
else
  echo "GitHub CLI already authenticated."
fi

# Set Github Creds as default
git config --global credential.helper '!gh auth git-credential'

# Clone your target repository
sudo rm -rf interactivebrokers2
gh repo clone https://github.com/arslan-qamar/interactivebrokers2.git

cd ~/interactivebrokers2

devbox init || true

exec devbox shell

# Install Code and Open 
sudo apt update 
sudo apt install code
code ~/interactivebrokers2 &
