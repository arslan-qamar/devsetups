# Shared folder for Vagrant VMs

This role creates `~/VMShared` on the host and makes the same authenticated
Samba share available to every VM. Ubuntu mounts it at `/shared`; Windows maps
it to `S:`.

Both Ubuntu and Windows authenticate to the same Samba share as the host user.
Guests discover the host address from their active Vagrant SSH connection, so
the configuration does not assume a particular libvirt subnet. Samba keeps a
separate password hash; register the host username once and choose the same
password as the host login if desired. Set `vm_shared_folder_samba_hosts_allow`
to narrower CIDRs if access should be limited beyond the default loopback and
RFC1918 private networks. When UFW is active, the role opens TCP 445 only for
those private networks; authentication is still mandatory.

```bash
ansible-playbook main.yml -i 'localhost,' --connection=local \
  --extra-vars 'state=present' --tags vm_shared_folder -K
sudo smbpasswd -a "$USER"
export VAGRANT_SHARED_SMB_USER="$USER"
export VAGRANT_SHARED_SMB_PASSWORD='your Samba password'
```

Override `vm_shared_folder_path` in Ansible if a different host directory is
required. Set `VAGRANT_SHARED_DISABLED=1` to disable the mount for a particular
Vagrant run. If `VAGRANT_SHARED_SMB_PASSWORD` is not set, Vagrant skips the
optional mount and continues with all other provisioning.
An unavailable server or failed mount also produces a warning without aborting
unrelated VM provisioning.

Uninstalling removes the managed share configuration, but never deletes the
shared data directory or the host user's Samba account.
