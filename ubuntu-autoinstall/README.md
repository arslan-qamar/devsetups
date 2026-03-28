# Ubuntu Auto-Install Setup

This guide provides instructions to build a libvirt-compatible base box using Packer with QEMU/KVM. Follow the steps below to set up your environment and create the required image.

## Prerequisites

Ensure the following tools are installed on your system:
- [Packer](https://www.packer.io/)
- QEMU/KVM
- libvirt
- virt-manager (optional GUI)

## Setup Instructions

To set up the host environment with QEMU/KVM, libvirt, Packer, and Vagrant, run the following command:

```bash
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" | bash -s "main.yml" "localhost," "local" "install" "qemu,kvm,libvirt,virtmanager,packer,vagrant"
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
4. Run Packer to build the VM image with SPICE guest integration for automatic display resize

Once the `ubuntu-dev.box` is built, add it to Vagrant using the generated metadata file instead of the raw box archive:

```bash
vagrant box add output/ubuntu-dev.json
```

The metadata file includes a box version and checksum so Vagrant can track updates cleanly without falling back to timestamp-based change detection.

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

The base image now installs `spice-vdagent`, and the shared libvirt Vagrant configuration exposes the SPICE agent channel. After pulling these changes, rebuild the base box and recreate or repackage VMs that still use an older box build if you want automatic display resize support in SPICE clients.

For more details, refer to the respective README files in the application-specific folders.

