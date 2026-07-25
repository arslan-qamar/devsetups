---
type: Engineering Guide
title: Testing and Change Guide
description: Practical verification and change-impact guidance for Dev Setups Ansible roles, shared Vagrant behavior, base-box builds, and application VM profiles.
tags: [testing, ansible, vagrant, operations, maintenance]
---

# Testing and Change Guide

## What verification exists

This repository is primarily shell, Ruby Vagrant configuration, and Ansible. No dedicated unit-test suite was identified in the initial inventory. Confidence comes from syntax checks, narrow tagged runs, built-in role assertions, and real VM lifecycle validation.

### Ansible baseline

Validate the main playbook before changing its composition:

```bash
ansible-playbook --syntax-check -i 'localhost,' --connection=local main.yml
```

For a role change, run the narrowest appropriate tag set using an explicit inventory and state. The root bootstrap’s invocation semantics are documented in [Provisioning architecture](architecture/overview.md#system-shape); use the playbook directly when iterating locally to avoid cloning a fresh execution copy on every run.

Several roles contain runtime checks after installation:

- `docker` asserts the Docker service is running and verifies `docker ps` as the selected non-root user;
- `postgres` asserts an online cluster and verifies local plus password-authenticated TCP access;
- `microk8s` waits for readiness and writes a user kubeconfig.

These checks are implementation-level evidence, not a substitute for testing the surrounding host impact noted in the [Operations runbook](operations/runbook.md).

## Profile and VM validation

For a changed profile or reusable guest script:

1. Start from a current `ubuntu-dev` box or rebuild it if Packer/autoinstall/base-image behavior changed.
2. Export the required `VAGRANT_CUSTOM_KEY_PATH` when the profile does not set a default.
3. Use `vagrant up --provider=libvirt` from the target profile directory.
4. Confirm the profile’s generic `provision_validate_setup.sh` check passes: SSH key presence, secret GPG key, and global Git signing configuration.
5. Confirm profile-specific validation where present. The IBKR profile additionally checks the cloned repository, `.envrc` content, and TWS availability.
6. If disk behavior changed, exercise both a creation path and a subsequent `vagrant provision` or `vagrant reload --provision` with `VAGRANT_VM_DISK_SIZE_GB` set.

The common provisioner sequence and profile differences are canonical in [Project VM profile provisioning](workflows/profile-provisioning.md). Shared lifecycle behavior is canonical in [Ubuntu box and VM lifecycle](workflows/vm-lifecycle.md).

## Change impact matrix

| Change area | Inspect first | Minimum verification |
| --- | --- | --- |
| `main.yml` role ordering/tags | role task files and affected profile tag sets | `ansible-playbook --syntax-check`; narrow tag run. |
| A single role | its `tasks/main.yml`, defaults/vars, and role README | narrow present/absent run where supported; retain or extend built-in assertions. |
| `bootstrap.sh` | README and `host/README` | inspect argument mapping for inventory, connection, state, tags, and optional host phase; test without credentials unless explicitly authorized. |
| Packer/autoinstall | `ubuntu-autoinstall/bootstrap.sh`, `packer.pkr.hcl`, `user-data.tpl` | run build preflight, Packer build, then `vagrant box add output/ubuntu-dev.json`. |
| Shared Vagrant base | representative profile Vagrantfiles and resize/network helpers | `vagrant up`; network selection check; disk-growth lifecycle check if touched. |
| Guest provisioner scripts | all call sites under `dev vms/` | profile bring-up plus generic and profile-specific validation. |
| Bridge, graphics, or GPU scripts | [Operations runbook](operations/runbook.md) and actual host capability | test only on a recoverable host/VM; use supplied dry-run when available for GPU host setup. |

## Review points for future agents

- Preserve the `state` contract (`present` or `absent`) when changing roles or entrypoints.
- Do not assume roles run in dependency order beyond the sequence explicitly listed in `main.yml`.
- Avoid copying secrets into new documentation or profiles. Reference environment variable names and trusted secret-management flows only.
- Treat shared base changes as cross-profile changes. The base controls network discovery, libvirt network activation, SSH configuration, SPICE settings, timezone, and disk resize triggers.
- Keep operational reversibility intact: graphics patches have an unpatch path, GPU host setup has an uninstall script, and the bridge role includes a removal path.

## Git-informed maintenance notes

Recent changes concentrated on VM recoverability rather than new application behavior: direct-uplink network fallback and libvirt-network autostart, coordinated host/guest disk growth, and reversible graphics/GPU setup. When editing these areas, inspect recent Git history and retain the paired helper behavior rather than modifying only the visible Vagrantfile setting.

For the relevant source anchors, see the [Source map](reference/source-map.md).
