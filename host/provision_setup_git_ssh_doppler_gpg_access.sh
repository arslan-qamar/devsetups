#!/bin/bash
set -e

EMAIL="${EMAIL:-ravian720@gmail.com}"
KEY_PATH="$HOME/.ssh/id_ed25519"
MACHINE_NAME="${1:-$(hostname)}"

read -r -p "Git email [$EMAIL]: " EMAIL_INPUT
if [ -n "$EMAIL_INPUT" ]; then
  EMAIL="$EMAIL_INPUT"
fi

# Login to Doppler
echo "Logging into Doppler..."
if doppler whoami &>/dev/null; then
  echo "Already authenticated with Doppler, skipping login."
else
  doppler login -y
fi

echo "Setting up Git SSH access for $EMAIL on machine: $MACHINE_NAME"

# Generate SSH key pair if it doesn't already exist
if [ ! -f "$KEY_PATH" ]; then
  echo "Generating new ed25519 SSH key pair..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
  echo "SSH key pair generated at $KEY_PATH"
else
  echo "SSH key already exists at $KEY_PATH, skipping key generation."
fi

# Ensure correct permissions
chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"

# Start ssh-agent and add the key
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH"
echo "SSH key added to ssh-agent."

# Login to GitHub CLI
echo "Logging into GitHub CLI..."
if gh auth status &>/dev/null; then
  echo "Already authenticated with GitHub CLI, skipping login."
else
  gh auth login --git-protocol ssh --web
fi

# Add the public key to GitHub
echo "Adding SSH public key to GitHub with title: $MACHINE_NAME"
gh ssh-key add "${KEY_PATH}.pub" --title "$MACHINE_NAME"

# Verify SSH connection to GitHub
echo "Verifying SSH connection to GitHub..."
ssh -T git@github.com -o StrictHostKeyChecking=no || true

# Setup GPG signing from Doppler git-creds project
echo "Setting up Git GPG signing from Doppler..."
echo "Fetching GPG private key from Doppler..."
doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PRIVKEY.raw' > /tmp/privkey.asc
echo "Importing GPG private key..."
gpg --batch --yes --pinentry-mode loopback \
  --passphrase-file <(doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PASSPHRASE.raw') \
  --import /tmp/privkey.asc
rm -f /tmp/privkey.asc
echo "Extracting GPG key ID..."
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2)
echo "Configuring Git GPG signing with key: $GPG_KEY_ID..."
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global user.signingkey "$GPG_KEY_ID"
git config --global rebase.autostash true
git config --global merge.autostash true

# Set Git user identity from GitHub account
GIT_NAME="$(gh api user | jq -r .name)"
GIT_EMAIL="$(gh api user | jq -r .email)"
if [ -z "$GIT_NAME" ] || [ "$GIT_NAME" = "null" ]; then
  read -r -p "Git name: " GIT_NAME
fi
if [ -z "$GIT_EMAIL" ] || [ "$GIT_EMAIL" = "null" ]; then
  read -r -p "Git email: " GIT_EMAIL
fi
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
echo "Git user.name set to: $GIT_NAME"
echo "Git user.email set to: $GIT_EMAIL"

# Verify commit signing works
echo "Verifying commit signing..."
SIGN_TEST_DIR=$(mktemp -d)
git init "$SIGN_TEST_DIR" -q
git -C "$SIGN_TEST_DIR" config user.name "$GIT_NAME"
git -C "$SIGN_TEST_DIR" config user.email "$GIT_EMAIL"
git -C "$SIGN_TEST_DIR" config commit.gpgsign true
git -C "$SIGN_TEST_DIR" config user.signingkey "$GPG_KEY_ID"
touch "$SIGN_TEST_DIR/test"
git -C "$SIGN_TEST_DIR" add .
if git -C "$SIGN_TEST_DIR" commit -S -m "signing test" -q 2>&1; then
  echo "Commit signing verified successfully."
else
  echo "ERROR: Commit signing failed. Check your GPG key setup." >&2
  rm -rf "$SIGN_TEST_DIR"
  exit 1
fi
rm -rf "$SIGN_TEST_DIR"

echo "Git SSH access setup complete."
