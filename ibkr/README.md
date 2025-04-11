# Provision
vagrant up

## Runs the following for Interactive Brokers Tooling on VM startup : 
`wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/ibkr/interactivebrokers.yaml" "localhost," "local"`
