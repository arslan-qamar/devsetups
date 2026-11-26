# IBKR Trading Bot

This repository provides a virtualized environment for setting up and running an Interactive Brokers trading bot. The setup leverages **Vagrant** for provisioning and **Ansible** for configuration management, ensuring a consistent and reliable development environment.

## Features
- Automated provisioning of a virtual machine.
- Pre-configured tools and dependencies for Interactive Brokers trading bot.
- Streamlined setup process for development and testing.

## Prerequisites
- Install [Vagrant](https://www.vagrantup.com/).
- Install libvirt with QEMU/KVM and a GUI such as virt-manager.

## Setup Instructions

### Provision the Virtual Machine
Run the following command to set up the virtual machine and install necessary tools:

```bash
vagrant up
```

### Automated Tooling Setup
The main VM and both replicas use the same IBKR profile. Vagrant uploads the local `main.yml` and `roles/` and installs the selected tools in one Ansible run. To apply local role changes to an existing VM, run `vagrant provision` from its directory.

Load a GitHub-authorized key into the host SSH agent before provisioning. The guest uses the forwarded agent to clone `interactivebrokers2`. Git signing uses `GIT_NAME`, `GIT_EMAIL`, and `DOPPLER_SERVICE_TOKEN_GIT`. The project's `setup.sh` receives the IBKR paper, live, test, and service-account Doppler tokens configured by the profile.

## How It Works
1. **Provisioning**: Vagrant creates a virtual machine based on the provided configuration.
2. **Configuration**: Ansible applies configurations and installs required tools for the trading bot.

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request for any improvements or additional features.

## License
This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.
