#!/bin/bash
set -euo pipefail

GPG_DIR="$HOME/.gnupg"
GPG_PASSPHRASE_FILE="$GPG_DIR/git-signing-passphrase"
GPG_WRAPPER_PATH="$HOME/.local/bin/git-gpg-sign"

mkdir -p "$GPG_DIR" "$HOME/.local/bin"
chmod 700 "$GPG_DIR"
echo "Setting up Git GPG Signing..."
echo "Opening GPG private key..."
DOPPLER_TOKEN=$DOPPLER_SERVICE_TOKEN_GIT doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PRIVKEY.raw' > privkey.asc
echo "Opening GPG passphrase..."
DOPPLER_TOKEN=$DOPPLER_SERVICE_TOKEN_GIT doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PASSPHRASE.raw' > "$GPG_PASSPHRASE_FILE"
chmod 600 "$GPG_PASSPHRASE_FILE"
gpg --batch --yes --pinentry-mode loopback --passphrase-file "$GPG_PASSPHRASE_FILE" --import privkey.asc
rm -f privkey.asc
cat > "$GPG_WRAPPER_PATH" <<EOF
#!/bin/bash
exec gpg --batch --yes --pinentry-mode loopback --passphrase-file "$GPG_PASSPHRASE_FILE" "\$@"
EOF
chmod 700 "$GPG_WRAPPER_PATH"
echo "Importing GPG public key..."
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2)
echo "Setting up GPG signing for Git..."
git config --global commit.gpgsign true
echo "GPG signing enabled for tags"
git config --global tag.gpgSign true
git config --global gpg.program "$GPG_WRAPPER_PATH"
echo "Setting GPG key ID for Git with key: $GPG_KEY_ID..."
git config --global user.signingkey "$GPG_KEY_ID"
echo "Setting up Git user config from environment variables..."
if [ -n "$GIT_NAME" ]; then
  git config --global user.name "$GIT_NAME"
fi
if [ -n "$GIT_EMAIL" ]; then
  git config --global user.email "$GIT_EMAIL"
fi
git config --global rebase.autostash true
git config --global merge.autostash true