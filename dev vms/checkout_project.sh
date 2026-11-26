#!/usr/bin/env bash
set -euo pipefail

repository=${REPOSITORY_NAME:?REPOSITORY_NAME must be set}
project_dir="$HOME/$repository"
url="git@github.com:arslan-qamar/$repository.git"

if ! ssh-add -l >/dev/null; then
  echo 'Load a GitHub key into your host SSH agent with ssh-add before provisioning.' >&2
  exit 1
fi

# Published at https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
github_key='github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl'
install -d -m 700 "$HOME/.ssh"
known_hosts="$HOME/.ssh/known_hosts"
touch "$known_hosts"
if ! grep -Fxq "$github_key" "$known_hosts"; then
  printf '%s\n' "$github_key" >> "$known_hosts"
fi
export GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlgorithms=ssh-ed25519 -o IdentityFile=none'

if [[ ! -e "$project_dir" ]]; then
  git clone "$url" "$project_dir"
fi
if [[ ! -d "$project_dir/.git" && ! -f "$project_dir/.git" ]]; then
  echo "Expected a Git checkout at $project_dir" >&2
  exit 1
fi
git -C "$project_dir" ls-remote origin HEAD >/dev/null
