# Dev Setups
Repository to setup dev environments using Vagrant (Provisioning) and Ansible (Configuration / Tooling) for relevant Git Repos

## Runs the following for Tooling Setup: 
`wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "present" "deps,devbox,githubcli,vscode"`

## Pre-Requisties 
- Setup local VirtualBox setup
- Install Vagrant

