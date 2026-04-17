# Dev Setups

This repository provides a streamlined approach to setting up development environments using **Vagrant** for provisioning and **Ansible** for configuration and tooling. It is tailored to support relevant Git repositories and ensure a consistent development setup.

## Features
- Automated provisioning with Vagrant.
- QEMU/KVM + libvirt as the supported local virtualization stack.
- Configuration management and tooling setup using Ansible.
- Pre-configured roles for dependencies, development tools, Docker, GitHub CLI, VS Code, and more.

## Quick Start
To set up the basic tooling environment, run the following command:


```bash
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "deps,devbox,docker,githubcli,vscode"
```

## Running Ansible Playbook Against a VM
To run the Ansible playbook directly against a VM (for example, to configure MicroK8s on a remote host), use:

```bash
ansible-playbook -i '<vm-name.local | 192.168.0.*>,' -u ubuntu --ssh-common-args="-F $VAGRANT_SSH_CFG " $MAIN_ANSIBLE  --extra-vars "state=present target_hosts=<vm-name.local | 192.168.0.*>" -t="microk8s" -K
```

Replace `<vm-name.local | 192.168.0.*>` with your VM's Name or VM's IP address. This command uses the specified SSH config and runs the playbook with the `microk8s` tag. The `-K` flag will prompt for the sudo password if needed.

## Enable 3D Graphics After Provisioning
To enable the custom libvirt 3D graphics layout on a VM after it has already been created and provisioned, run:

```bash
./toolbox/libvirt/enable_3d_graphics.sh <domain|vm-name|vm-directory>
```

Examples:

```bash
./toolbox/libvirt/enable_3d_graphics.sh gaspeep
./toolbox/libvirt/enable_3d_graphics.sh gaspeep_vm
./toolbox/libvirt/enable_3d_graphics.sh "dev vms/gaspeep"
```

The command patches the libvirt domain XML to use the separate SPICE socket, `egl-headless`, and virtio video configuration, then restarts or starts the VM so the change takes effect.

## Libvirt Network After Host Reboot
If a VM created with `vagrant-libvirt` fails to start after a host reboot with `network 'vagrant-libvirt' is not active`, enable and start that network once on the host:

```bash
virsh -c qemu:///system net-autostart vagrant-libvirt
virsh -c qemu:///system net-start vagrant-libvirt
```

The shared Vagrant base file now also re-starts that network before `vagrant up` and marks it for autostart after the network exists, so future reboots do not require the manual step.

For bridged guest networking, the shared Vagrant base now prefers an active host bridge such as `br0`. If no host bridge exists, it falls back to the host's active uplink interface and attaches the guest in libvirt direct bridge mode instead of silently creating a private-only NIC. You can override the selected interface with `VAGRANT_BRIDGE=<interface>` before running `vagrant up`.

## Repository Structure
- **bootstrap.sh**: Entry point script for setting up the environment.
- **roles/**: Contains Ansible roles for various tools and configurations.
  - **deps/**: Handles dependencies.
  - **nodejs/**: Installs Node.js from NodeSource.
  - **devbox/**: Sets up the development box.
  - **docker/**: Configures Docker.
  - **githubcli/**: Installs and configures GitHub CLI.
  - **vscode/**: Sets up Visual Studio Code.
  - **zsh/**: Configures Zsh shell.
- **ubuntu-autoinstall/**: Contains files for Ubuntu auto-installation and Vagrant base setup.

To install Node.js on its own, run the playbook with the `nodejs` tag.

## How It Works
1. **Provisioning**: Vagrant is used to create and manage virtual machines.
2. **Configuration**: Ansible applies configurations and installs necessary tools.

For a comprehensive understanding of how all components work together, see the [Codebase Tutorial](codebase%20tutorial/index.md).

## Contributing
Contributions are welcome! Please fork the repository and submit a pull request for any improvements or additional features.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.



