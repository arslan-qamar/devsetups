# IBKR Trading Bot
To setup : https://github.com/arslan-qamar/interactivebrokers2.git (private repo)

## To Provision in VM (Setups tools and code repo in it)
```shell
  vagrant up   
```
##### Run the following command in terminal once guest additions are installed to reload kernel
```shell
sudo rcvboxadd reload
```

### Runs the following for Interactive Brokers Tooling on VM startup : 
`wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/main.yml" "localhost," "local", "present", "deps,devbox,docker,githubcli,vscode"`
