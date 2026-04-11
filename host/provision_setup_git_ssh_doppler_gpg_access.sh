#!/bin/bash
set -euo pipefail

EMAIL="${EMAIL:-ravian720@gmail.com}"
KEY_PATH="$HOME/.ssh/id_ed25519"
MACHINE_NAME="${1:-$(hostname)}"
STATE_DIR="$HOME/.config/devsetups"
STATE_FILE="$STATE_DIR/host_credentials.env"
KEY_CREATED="false"
GPG_IMPORTED_BY_SETUP="false"
GPG_DIR="$HOME/.gnupg"
GPG_PASSPHRASE_FILE="$GPG_DIR/git-signing-passphrase"
GPG_WRAPPER_PATH="$HOME/.local/bin/git-gpg-sign"

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
  KEY_CREATED="true"
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
  gh auth refresh -h github.com -s admin:public_key
fi

# Add the public key to GitHub
echo "Adding SSH public key to GitHub with title: $MACHINE_NAME"
gh ssh-key add "${KEY_PATH}.pub" --title "$MACHINE_NAME"

# Verify SSH connection to GitHub
echo "Verifying SSH connection to GitHub..."
ssh -T git@github.com -o StrictHostKeyChecking=no || true

# Setup GPG signing from Doppler git-creds project
echo "Setting up Git GPG signing from Doppler..."
mkdir -p "$GPG_DIR" "$HOME/.local/bin"
chmod 700 "$GPG_DIR"
echo "Fetching GPG private key from Doppler..."
doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PRIVKEY.raw' > /tmp/privkey.asc
IMPORTED_GPG_FINGERPRINT=$(gpg --show-keys --with-colons /tmp/privkey.asc | awk -F: '/^fpr:/ {print $10; exit}')
if ! gpg --list-secret-keys --with-colons "$IMPORTED_GPG_FINGERPRINT" >/dev/null 2>&1; then
  GPG_IMPORTED_BY_SETUP="true"
fi
echo "Importing GPG private key..."
doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PASSPHRASE.raw' > "$GPG_PASSPHRASE_FILE"
chmod 600 "$GPG_PASSPHRASE_FILE"
gpg --batch --yes --pinentry-mode loopback \
  --passphrase-file "$GPG_PASSPHRASE_FILE" \
  --import /tmp/privkey.asc
rm -f /tmp/privkey.asc
cat > "$GPG_WRAPPER_PATH" <<EOF
#!/bin/bash
exec gpg --batch --yes --pinentry-mode loopback --passphrase-file "$GPG_PASSPHRASE_FILE" "\$@"
EOF
chmod 700 "$GPG_WRAPPER_PATH"
echo "Extracting GPG key ID..."
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2)
GPG_FINGERPRINT=$(gpg --with-colons --fingerprint "$GPG_KEY_ID" | awk -F: '/^fpr:/ {print $10; exit}')
echo "Configuring Git GPG signing with key: $GPG_KEY_ID..."
git config --global commit.gpgsign true
git config --global tag.gpgSign true
git config --global gpg.program "$GPG_WRAPPER_PATH"
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

mkdir -p "$STATE_DIR"
cat > "$STATE_FILE" <<EOF
KEY_PATH="$KEY_PATH"
KEY_CREATED="$KEY_CREATED"
GPG_KEY_ID="$GPG_KEY_ID"
GPG_FINGERPRINT="$GPG_FINGERPRINT"
GPG_IMPORTED_BY_SETUP="$GPG_IMPORTED_BY_SETUP"
EOF
chmod 600 "$STATE_FILE"

echo "Git SSH access setup complete."
