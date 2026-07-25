---
type: Runbook
title: Operations and Safety Runbook
description: Operational guidance for high-impact Dev Setups actions involving host networking, libvirt graphics, GPU passthrough, credential material, storage, and local services.
tags: [operations, security, libvirt, networking, gpu]
---

# Operations and Safety Runbook

## Host networking

The shared Vagrant base tries to use an existing active bridge or active uplink and falls back to private DHCP. If a host needs a managed `br0`, the `bridge` Ansible role uses NetworkManager to identify the default uplink, create/configure the bridge, make the uplink a bridge slave, and bring both connections up. This can interrupt host connectivity.

Before applying `bridge`:

- run it only with a deliberate tag set and console access;
- confirm the default interface and active NetworkManager connection are the intended ones;
- understand that the role uses `br0` by default and configures automatic IPv4/IPv6 addressing on it.

On an `absent` run, the role deletes the configured bridge and attempts to restore one bridge-slave connection to an ordinary connection. This operational path **supports** the shared network selection in [Ubuntu box and VM lifecycle](../workflows/vm-lifecycle.md#network-selection-and-lifecycle), but it is not required when direct uplink attachment is sufficient.

If libvirt reports that `vagrant-libvirt` is inactive after a reboot, run:

```bash
virsh -c qemu:///system net-autostart vagrant-libvirt
virsh -c qemu:///system net-start vagrant-libvirt
```

The shared base also performs these actions around `vagrant up` when the network exists.

## Graphics and GPU

### Restore standard graphics

The repository supports an optional post-creation patch that changes libvirt XML to add an EGL-headless and separate SPICE socket arrangement. It is not part of normal Vagrant provisioning. If a patched VM fails with `eglInitialize failed: EGL_NOT_INITIALIZED`, restore the normal SPICE layout:

```bash
./toolbox/libvirt/disable_3d_graphics.sh <domain|vm-name|vm-directory>
```

The wrapper calls the shared unpatch script. Use `enable_3d_graphics.sh` only when the host’s EGL/render-node capability is known to work. The May graphics change added the reversal path specifically so a failed graphics experiment has a defined recovery route.

### Configure GPU passthrough

GPU passthrough has two separate stages:

1. On the **host**, run `sudo ./toolbox/libvirt/configure_gpu_passthrough_host.sh` (optionally with `--vfio-pci-ids` or `--dry-run`). It modifies GRUB IOMMU arguments, writes VFIO binding/module configuration, rebuilds initramfs and GRUB, and requires a reboot.
2. In the **VM profile**, set `LIBVIRT_GPU_PCI_DEVICES` to validated PCI addresses before using `dev vms/gpuenabled/Vagrantfile`. Only then does the profile attach PCI devices and enable host-passthrough CPU, Q35, and hidden KVM.

The host script has hardware-specific default PCI IDs and must be overridden after hardware changes. Verify that intended GPU functions bind to `vfio-pci` after reboot before starting the VM. The uninstall companion can reverse the host setup. This host preparation **enables** the opt-in profile behavior in [Project VM profile provisioning](../workflows/profile-provisioning.md#profile-examples).

## Host credentials and signing

Passing a sixth `true` argument to the root bootstrap enables an *optional* host credential phase after Ansible roles complete. It is prompt-gated on a controlling terminal; a non-interactive run skips it. The host script can create/use an SSH key, use Doppler and GitHub CLI, import signing material, and configure global Git signing. Its uninstall cleanup is local-only so it does not rely on credential tools that may already have been removed.

Do not treat this as a generic noninteractive bootstrap mechanism. It materializes sensitive private-key material locally, and VM profiles may separately copy an SSH private key into guests. Keep secret values out of tracked files and use variable names/configuration mechanisms rather than pasting values into commands or docs. The guest-side implications are described in [Project VM profile provisioning](../workflows/profile-provisioning.md#credential-boundary).

## Storage and local services

- **Disk growth:** Set `VAGRANT_VM_DISK_SIZE_GB` to a positive integer only when intending to grow capacity. The host and guest helper scripts grow capacity; they do not support shrinking. Follow [VM lifecycle](../workflows/vm-lifecycle.md#resize-an-existing-vm).
- **Docker:** the role adds the resolved login user to the `docker` group and verifies passwordless `docker ps`. Membership conveys substantial host control; review the selected user before applying it.
- **MicroK8s:** the role installs the classic snap, enables DNS, storage, ingress, registry, and dashboard, adds the user to `microk8s`, and writes `~/.kube/config` mode `0600`. A new login/session may be required for group membership.
- **PostgreSQL:** the role verifies an online cluster, sets the `postgres` password, and validates TCP password authentication. Its defaults contain a disposable-environment fallback; provide a deliberate password for any non-disposable environment.

## Automation context

The repository includes a scheduled/manual GitHub Actions workflow at [`.github/workflows/openwiki-update.yml`](../../.github/workflows/openwiki-update.yml) that installs OpenWiki and opens documentation-update pull requests. It has `contents: write` and `pull-requests: write` permissions and reads provider/tracing credentials from GitHub secrets. Treat that workflow as documentation automation, not as validation of provisioning behavior.

For change verification, use [Testing and change guide](../testing-and-change-guide.md).
