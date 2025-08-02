#!/bin/bash
echo $DOPPLER_SERVICE_TOKEN_IBKR_LIVE | doppler configure set token --scope /
# Install dependencies
sudo apt-get update
sudo apt-get install -y curl tar unzip

# Download runner
GH_RUNNER_VERSION="2.325.0"
GH_OWNER="arslan-qamar"
GH_REPO="interactivebrokers2"

# Repository permissions
#   Read access to metadata
#   Read and Write access to administration
IBKR_GH_TOKEN=$(doppler secrets -p ibkr-trading-bot -c live --json --raw | jq -r '.IBKR_GH_TOKEN.raw')

GH_TOKEN=$(curl -X POST -H "Authorization: token $IBKR_GH_TOKEN" https://api.github.com/repos/arslan-qamar/interactivebrokers2/actions/runners/registration-token | jq -r .token)

mkdir -p actions-runner && cd actions-runner
curl -O -L https://github.com/actions/runner/releases/download/v${GH_RUNNER_VERSION}/actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz
tar xzf actions-runner-linux-x64-${GH_RUNNER_VERSION}.tar.gz  

echo "Setting up GitHub Actions runner..."
./config.sh --unattended \
  --url https://github.com/$GH_OWNER/$GH_REPO \
  --token $GH_TOKEN \
  --name K8s \
  --labels Ibkr \
  --work _work

echo "Installing GitHub Actions runner service..."
sudo ./svc.sh install

echo "Starting GitHub Actions runner service..."
sudo ./svc.sh start
