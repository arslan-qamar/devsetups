# Ubuntu Auto-Install Setup

This guide provides instructions to build a package image using Packer and VirtualBox. Follow the steps below to set up your environment and create the required image.

## Prerequisites

Ensure the following tools are installed on your system:
- [Packer](https://www.packer.io/)
- [VirtualBox](https://www.virtualbox.org/)

## Setup Instructions

To set up the host environment with VirtualBox, Packer, and Vagrant, run the following command:

```bash
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "virtualbox,packer,vagrant"
```

## Building the Image

Run the bootstrap script to create the Packer VM image:

```bash
./bootstrap.sh
```

This script will:
1. Prompt you to create a custom password for the 'ubuntu' user
2. Generate an SSH key pair (vagrant_custom_key) for secure authentication
3. Create the `user-data` file with your custom settings
4. Run Packer to build the VM image

Once the `ubuntu-dev.box` is built, add it to Vagrant using the following command:

```bash
vagrant box add ubuntu-dev output/ubuntu-dev.box
```

## Default Configuration

The VM is configured with:
- **Username:** `ubuntu`
- **Password:** Your custom password (set during bootstrap)
- **SSH Authentication:** Key-based (using vagrant_custom_key)

## Running the Application

Navigate to the application-specific folders (e.g., `ibkr`) and start the Vagrant environment:

```bash
cd ibkr
vagrant up
```

## Additional Information

For more details, refer to the respective README files in the application-specific folders.

