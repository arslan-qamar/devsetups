#!/bin/bash
set -e
echo "Validating basic setup..."

# SSH key
if [ "${1:-}" = "--forwarded-agent" ]; then
  ssh-add -l >/dev/null || { echo "ERROR: No forwarded SSH identity"; exit 1; }
else
  [ -f ~/.ssh/id_ed25519 ] || (echo "ERROR: SSH key missing!" && exit 1)
fi

# GPG key
gpg --list-secret-keys | grep sec || (echo "ERROR: No GPG key found!" && exit 1)

# Git config
git config --global --get user.name || (echo "ERROR: Git user.name not set!" && exit 1)
git config --global --get user.email || (echo "ERROR: Git user.email not set!" && exit 1)
git config --global --get user.signingkey || (echo "ERROR: Git signingkey not set!" && exit 1)
git config --global --get gpg.program || (echo "ERROR: Git gpg.program not set!" && exit 1)

echo "All basic validation checks passed."
