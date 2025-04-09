# Dev Setups
Repository to shell scripts to setup dev environments for relevant Git Repos


## Interactive Brokers 
`wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/InteractiveBrokers.sh?ts=$(date +%s)" | bash`

## Interactive Brokers using Ansible
`wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/interactivebrokers.yaml" "localhost," "local"`
