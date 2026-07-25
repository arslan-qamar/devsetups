---
type: Reference
title: Repository Source Map
description: Practical map of Dev Setups entrypoints, role catalog, box build assets, VM profiles, operational scripts, and pre-existing documentation.
tags: [reference, navigation, ansible, vagrant, libvirt]
---

# Repository Source Map

## Execution entrypoints

| Location | Purpose | Follow-up |
| --- | --- | --- |
| [`bootstrap.sh`](../../bootstrap.sh) | Cross-distribution bootstrapper that installs Ansible/Git, clones a fresh execution copy, maps install/uninstall to state, and runs a playbook with optional tags. | [Architecture overview](../architecture/overview.md) |
| [`main.yml`](../../main.yml) | Ordered, tagged role composition for local or overridden `target_hosts`. | [Testing and change guide](../testing-and-change-guide.md) |
| [`README.md`](../../README.md) | Primary user-facing commands for base tooling, remote VM Ansible, graphics recovery, network recovery, and GPU passthrough. | [Operations runbook](../operations/runbook.md) |
| [`host/`](../../host/) | Optional host SSH, Git, Doppler, and GPG setup/cleanup documentation and scripts. | [Operations runbook](../operations/runbook.md#host-credentials-and-signing) |

## Configuration roles

[`roles/`](../../roles/) contains 29 tagged roles. Each role generally has `tasks/main.yml`; many also have a README and optional defaults/vars. `main.yml` is the source of truth for which tags are available and their sequence.

| Concern | Role directories |
| --- | --- |
| Foundation/languages | `deps`, `nodejs`, `go`, `python`, `dotnet`, `ruby`, `zsh` |
| Developer applications | `devbox`, `githubcli`, `vscode`, `postman`, `mongodb_compass`, `rider` |
| Virtualization/containers | `docker`, `qemu`, `kvm`, `libvirt`, `virtmanager`, `vagrant`, `packer`, `bridge` |
| Data/platform | `postgres`, `helm`, `kubectl`, `argocd`, `microk8s` |
| Configuration/secret tools | `hcp`, `doppler` |

The role catalog **supplies** both general host/guest configuration and the prerequisites for [Ubuntu box and VM lifecycle](../workflows/vm-lifecycle.md). Consult the role README before changing a vendor-specific installation procedure.

## Base-box and shared VM assets

| Location | Purpose |
| --- | --- |
| [`ubuntu-autoinstall/bootstrap.sh`](../../ubuntu-autoinstall/bootstrap.sh) | Host preflight, optional prerequisite installation, input generation, Packer build, and local box metadata creation. |
| [`ubuntu-autoinstall/packer.pkr.hcl`](../../ubuntu-autoinstall/packer.pkr.hcl) | QEMU/KVM Packer source and libvirt Vagrant packaging configuration. |
| [`ubuntu-autoinstall/user-data.tpl`](../../ubuntu-autoinstall/user-data.tpl) and `meta-data` | Cloud-init/autoinstall inputs for the base image. |
| [`ubuntu-autoinstall/vagrant-base/VagrantBaseFile`](../../ubuntu-autoinstall/vagrant-base/VagrantBaseFile) | Inherited Vagrant base: network selection, libvirt defaults, SPICE, timezone, and resize triggers. |
| [`ubuntu-autoinstall/vagrant-base/resize_libvirt_primary_disk.sh`](../../ubuntu-autoinstall/vagrant-base/resize_libvirt_primary_disk.sh) | Host-side primary-disk growth helper. |
| [`ubuntu-autoinstall/vagrant-base/resize_guest_root_fs.sh`](../../ubuntu-autoinstall/vagrant-base/resize_guest_root_fs.sh) | Guest root partition/filesystem growth helper. |

These assets collectively **produce and operate** the base described in [Ubuntu box and VM lifecycle](../workflows/vm-lifecycle.md).

## VM profiles and reusable guest scripts

| Location | Purpose |
| --- | --- |
| [`dev vms/ibkr/Vagrantfile`](../../dev%20vms/ibkr/Vagrantfile) | Full project profile with repository setup, environment configuration, signing, Kubernetes/dev tools, project setup, and additional validation. |
| [`dev vms/portfoliozen/Vagrantfile`](../../dev%20vms/portfoliozen/Vagrantfile) | Profile with a tailored language, database, and tool tag set; latest profile commit added Ruby. |
| [`dev vms/gpuenabled/Vagrantfile`](../../dev%20vms/gpuenabled/Vagrantfile) | Optional PCI GPU passthrough profile. |
| [`dev vms/test/Vagrantfile`](../../dev%20vms/test/Vagrantfile), [`dev vms/gaspeep/Vagrantfile`](../../dev%20vms/gaspeep/Vagrantfile) | Additional profile variants. |
| [`dev vms/provision_01_install_bootstrap.sh`](../../dev%20vms/provision_01_install_bootstrap.sh) through [`provision_validate_setup.sh`](../../dev%20vms/provision_validate_setup.sh) | Shared guest bootstrap, SSH, clone, environment, signing, tools, project setup, and validation steps. |

These profile sources **extend** the shared base and are documented in [Project VM profile provisioning](../workflows/profile-provisioning.md).

## Host operations and documentation automation

| Location | Purpose |
| --- | --- |
| [`toolbox/libvirt/configure_gpu_passthrough_host.sh`](../../toolbox/libvirt/configure_gpu_passthrough_host.sh) / `uninstall_gpu_passthrough_host.sh` | Reversible host IOMMU/VFIO configuration for passthrough. |
| [`toolbox/libvirt/enable_3d_graphics.sh`](../../toolbox/libvirt/enable_3d_graphics.sh) / `disable_3d_graphics.sh` | Thin user commands for applying/reversing post-creation graphics XML changes. |
| [`ubuntu-autoinstall/vagrant-base/patch_libvirt_graphics.sh`](../../ubuntu-autoinstall/vagrant-base/patch_libvirt_graphics.sh) / `unpatch_libvirt_graphics.sh` | Shared graphics XML implementation and restoration. |
| [`.github/workflows/openwiki-update.yml`](../../.github/workflows/openwiki-update.yml) | Scheduled/manual OpenWiki documentation update workflow. |
| [`codebase tutorial/`](../../codebase%20tutorial/) | Existing broad tutorial pages; useful historical orientation, while this wiki is the concise maintenance map. |

For safety and recovery procedures, these sources **feed into** the [Operations runbook](../operations/runbook.md).
