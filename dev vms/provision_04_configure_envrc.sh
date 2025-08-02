#!/bin/bash
echo $DOPPLER_SERVICE_TOKEN_IBKR_TEST | doppler configure set token --scope ~/interactivebrokers2
cd interactivebrokers2
rm -f .envrc || true
./create-envrc.sh
