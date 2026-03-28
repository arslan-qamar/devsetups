#!/bin/bash
set -euo pipefail

STATE_FILE="$HOME/.config/devsetups/host_credentials.env"
KEY_PATH=""
KEY_CREATED="false"
GPG_KEY_ID=""
GPG_FINGERPRINT=""
GPG_IMPORTED_BY_SETUP="false"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

echo "Cleaning up local SSH and GPG materials..."

if [ "$KEY_CREATED" = "true" ] && [ -n "${KEY_PATH:-}" ] && [ -f "$KEY_PATH" ]; then
  rm -f "$KEY_PATH" "${KEY_PATH}.pub"
  echo "Removed SSH key pair at $KEY_PATH"
else
  echo "No SSH key created by this setup was tracked for removal."
fi

if [ -f "$STATE_FILE" ] && command -v git >/dev/null 2>&1; then
  git config --global --unset-all user.signingkey || true
  git config --global --unset-all commit.gpgsign || true
  git config --global --unset-all tag.gpgSign || true
  echo "Removed Git signing configuration."
elif [ -f "$STATE_FILE" ]; then
  echo "git not available, skipping Git config cleanup."
else
  echo "No tracked host credential state found, skipping Git config cleanup."
fi

if [ "$GPG_IMPORTED_BY_SETUP" = "true" ] && command -v gpg >/dev/null 2>&1; then
  if [ -n "${GPG_FINGERPRINT:-}" ]; then
    gpg --batch --yes --delete-secret-keys "$GPG_FINGERPRINT" || true
    gpg --batch --yes --delete-keys "$GPG_FINGERPRINT" || true
    echo "Attempted to remove GPG key $GPG_FINGERPRINT"
  elif [ -n "${GPG_KEY_ID:-}" ]; then
    gpg --batch --yes --delete-secret-keys "$GPG_KEY_ID" || true
    gpg --batch --yes --delete-keys "$GPG_KEY_ID" || true
    echo "Attempted to remove GPG key $GPG_KEY_ID"
  else
    echo "No tracked GPG key found to remove."
  fi
elif [ "$GPG_IMPORTED_BY_SETUP" = "true" ]; then
  echo "gpg not available, skipping GPG key cleanup."
else
  echo "No GPG key imported by this setup was tracked for removal."
fi

rm -f "$STATE_FILE"
echo "Local host SSH/GPG cleanup complete."