# IBKR Trading Bot

This repository provides a virtualized environment for setting up and running an Interactive Brokers trading bot. The setup leverages **Vagrant** for provisioning and **Ansible** for configuration management, ensuring a consistent and reliable development environment.

## Features
- Automated provisioning of a virtual machine.
- Pre-configured tools and dependencies for Interactive Brokers trading bot.
- Streamlined setup process for development and testing.

## Prerequisites
- Install [Vagrant](https://www.vagrantup.com/).
- Install a supported virtualization provider (e.g., VirtualBox).

## Setup Instructions

### Provision the Virtual Machine
Run the following command to set up the virtual machine and install necessary tools:

```bash
vagrant up
```

### Automated Tooling Setup
On VM startup, the following command is executed to configure the environment:

```bash
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/main.yml" "localhost," "local" "install" "deps,devbox,docker,githubcli,vscode"
```

## How It Works
1. **Provisioning**: Vagrant creates a virtual machine based on the provided configuration.
2. **Configuration**: Ansible applies configurations and installs required tools for the trading bot.

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request for any improvements or additional features.

## License
This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.
