#!/usr/bin/env bash
# Script to delete all Doppler service tokens for IBKR and GIT using the root toolbox script

set -euo pipefail

# Import the delete_tokens function from the root toolbox script
source "$(dirname "$0")/../../toolbox/delete_doppler_service_tokens.sh"

# Invoke delete_tokens for each required project/config
delete_tokens ibkr-trading-bot test
delete_tokens ibkr-trading-bot paper
delete_tokens ibkr-trading-bot live

