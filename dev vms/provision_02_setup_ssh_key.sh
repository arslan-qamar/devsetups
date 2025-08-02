#!/bin/bash
echo "Setting up Host SSH key for git clone..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  echo "Copying Host SSH key for git clone..."
  mv /tmp/id_ed25519 ~/.ssh/id_ed25519
  mv /tmp/id_ed25519.pub ~/.ssh/id_ed25519.pub
else
  echo "SSH key file already found at ~/.ssh/id_ed25519, skipping SSH key setup."
fi
