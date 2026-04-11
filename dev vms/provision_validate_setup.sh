#!/bin/bash
set -e
echo "Validating basic setup..."

# SSH key
[ -f ~/.ssh/id_ed25519 ] || (echo "ERROR: SSH key missing!" && exit 1)

# GPG key
gpg --list-secret-keys | grep sec || (echo "ERROR: No GPG key found!" && exit 1)

# Git config
git config --global --get user.name || (echo "ERROR: Git user.name not set!" && exit 1)
git config --global --get user.email || (echo "ERROR: Git user.email not set!" && exit 1)
git config --global --get user.signingkey || (echo "ERROR: Git signingkey not set!" && exit 1)

echo "All basic validation checks passed."
