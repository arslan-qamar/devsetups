---
type: Project Guide
title: Dev Setups Quickstart
description: Entry point for the Dev Setups repository, covering tagged Ansible configuration, Ubuntu libvirt base boxes, and application-specific Vagrant VMs.
tags: [ansible, vagrant, libvirt, packer, development-environments]
---

# Dev Setups Quickstart

## What this repository does

Dev Setups automates Linux development environments around four layers:

1. **Ansible roles** install or remove workstation and development tooling through [`main.yml`](../main.yml).
2. **Packer plus Ubuntu autoinstall** builds the `ubuntu-dev` libvirt box.
3. **A shared Vagrant base** turns that box into a KVM/libvirt VM with networking, SPICE, timezone, and optional disk-growth behavior.
4. **VM profiles** select tool tags and project setup steps for environments such as IBKR and PortfolioZen.

The system architecture, ownership boundaries, and source entrypoints are described in [Architecture overview](architecture/overview.md). For a file-oriented map, use the [Source map](reference/source-map.md); for available checks and change guidance, use the [Testing and change guide](testing-and-change-guide.md).

## Choose a starting path

| Goal | Start here | What to know first |
| --- | --- | --- |
| Configure a host or an existing VM | [`bootstrap.sh`](../bootstrap.sh) with selected `main.yml` tags | See [Architecture overview](architecture/overview.md) and [Testing and change guide](testing-and-change-guide.md). |
| Build or update the reusable Ubuntu box | [`ubuntu-autoinstall/bootstrap.sh`](../ubuntu-autoinstall/bootstrap.sh) | Follow [VM lifecycle](workflows/vm-lifecycle.md); it checks KVM, libvirt, and the Vagrant libvirt plugin. |
| Create a project VM | a profile under [`dev vms/`](../dev%20vms/) and `vagrant up --provider=libvirt` | Read [Profile provisioning](workflows/profile-provisioning.md) before supplying profile environment variables. |
| Diagnose networking, graphics, GPU, storage, or credential behavior | repo README and host/libvirt scripts | Use the focused [Operations runbook](operations/runbook.md). |
| Change the automation safely | role/task or Vagrant sources | Follow [Testing and change guide](testing-and-change-guide.md), then consult the [Source map](reference/source-map.md). |

## Fast paths

### Apply a narrow set of roles

The root bootstrap script installs Ansible and Git if needed, clones a fresh execution copy of this repository, maps `install` to `state=present` (and `uninstall` to `state=absent`), then invokes the selected playbook and tags. The repository README’s basic-tooling example is:

```bash
wget --header="Cache-Control: no-cache" -qO- "https://raw.githubusercontent.com/arslan-qamar/devsetups/refs/heads/main/bootstrap.sh?ts=$(date +%s)" \
  | bash -s "main.yml" "localhost," "local" "install" "deps,devbox,docker,githubcli,vscode"
```

`main.yml` is the canonical tag catalog. The full role ordering and category guide live in [Architecture overview](architecture/overview.md#ansible-role-catalog).

### Build the `ubuntu-dev` box

From [`ubuntu-autoinstall/`](../ubuntu-autoinstall/), run `./bootstrap.sh`. It can bootstrap host virtualization prerequisites, prompts for the guest password and SSH key material, builds the Packer image, and emits metadata for:

```bash
vagrant box add output/ubuntu-dev.json
```

The exact build prerequisites and box-to-VM handoff are documented in [VM lifecycle](workflows/vm-lifecycle.md#build-and-register-the-base-box).

### Bring up a profile VM

Set the key path required by the shared base (unless the profile supplies a default), enter a profile directory, and start libvirt provisioning:

```bash
export VAGRANT_CUSTOM_KEY_PATH=/path/to/vagrant_custom_key
cd "dev vms/portfoliozen"
vagrant up --provider=libvirt
```

Profiles inherit the shared VM configuration, then add project-specific provisioning. [Profile provisioning](workflows/profile-provisioning.md) explains the common sequence and the IBKR profile’s additional requirements.

## Important operating constraints

- **Use tags intentionally.** The root playbook includes workstation tools, virtualization, databases, Kubernetes, and host network configuration; it does not declare role metadata dependencies. The chosen tags determine the scope of a run.
- **Expect privileged host changes.** Roles manage packages, services, groups, external package sources, and—in the `bridge` role—NetworkManager connections. Read [Operations runbook](operations/runbook.md#host-networking) before changing host networking.
- **Treat profile credentials as sensitive.** Several profiles copy the host SSH private key into the guest and pass credential-related environment variables to guest provisioners. This is a deliberate host/guest boundary with material risk; see [Profile provisioning](workflows/profile-provisioning.md#credential-boundary).
- **Size growth is opt-in and only grows.** `VAGRANT_VM_DISK_SIZE_GB` coordinates host disk expansion with guest filesystem expansion. See [VM lifecycle](workflows/vm-lifecycle.md#resize-an-existing-vm).

## Wiki map

- [Architecture overview](architecture/overview.md) — components, control boundaries, role catalog, and source-of-truth hierarchy.
- [VM lifecycle](workflows/vm-lifecycle.md) — base-box build, shared Vagrant behavior, and storage growth.
- [Profile provisioning](workflows/profile-provisioning.md) — reusable guest provisioning sequence and project profiles.
- [Operations runbook](operations/runbook.md) — recovery and safety notes for networking, graphics, GPU passthrough, host credentials, and databases.
- [Testing and change guide](testing-and-change-guide.md) — available checks and change impact guidance.
- [Source map](reference/source-map.md) — practical navigation through entrypoints, roles, profiles, and existing documentation.

## Backlog

- **Role-by-role behavior catalog** — source anchor: `roles/*/tasks/main.yml`; deferred because 29 roles are present and this initial wiki maps the tag catalog and high-risk roles rather than duplicating each role’s README.
- **Autoinstall field reference** — source anchor: `ubuntu-autoinstall/user-data.tpl`; deferred because the initial wiki documents its build boundary but not every cloud-init setting.
