#!/usr/bin/env bash
# Script to delete all Doppler service tokens for GIT using the root toolbox script

set -euo pipefail

# Import the delete_tokens function from the root toolbox script
source "delete_doppler_service_tokens.sh"

# Invoke delete_tokens for each required project/config

delete_tokens git-creds dev_personal

