#!/bin/bash
echo $DOPPLER_SERVICE_TOKEN_GIT | doppler configure set token --scope /
echo "Setting up Git GPG Signing..."
echo "Opening GPG private key..."
doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PRIVKEY.raw' > privkey.asc
echo "Opening GPG passphrase..."
gpg --batch --yes --pinentry-mode loopback --passphrase-file <(doppler secrets -p git-creds -c dev_personal --json --raw | jq -r '.PASSPHRASE.raw') --import privkey.asc
echo "Importing GPG public key..."
GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/^sec/{print $2}' | cut -d'/' -f2)
echo "Setting up GPG signing for Git..."
git config --global commit.gpgsign true
echo "GPG signing enabled for tags"
git config --global tag.gpgSign true
echo "Setting GPG key ID for Git with key: $GPG_KEY_ID..."
git config --global user.signingkey $GPG_KEY_ID
echo "Setting up Git user config from environment variables..."
if [ -n "$GIT_NAME" ]; then
  git config --global user.name "$GIT_NAME"
fi
if [ -n "$GIT_EMAIL" ]; then
  git config --global user.email "$GIT_EMAIL"
fi
