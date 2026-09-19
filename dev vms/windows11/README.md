# Windows 11 Vagrant VM

This profile starts a fresh Windows VM from the locally registered `windows11-home-dev` base box.

If the VM shows Windows Recovery with `winload.efi` error `0xc000000f`, or starts the region, keyboard, and device-name wizard, the registered box predates a required base-box fix. Rebuild and register the box, then recreate the VM:

```bash
cd /home/arslan/devsetups/windows11-autoinstall
./bootstrap.sh

cd '/home/arslan/devsetups/dev vms/windows11'
vagrant destroy -f
vagrant up --provider=libvirt
```

```bash
cd '/home/arslan/devsetups/dev vms/windows11'
vagrant up --provider=libvirt
vagrant winssh
```

The profile automatically creates writable UEFI NVRAM at `.vagrant/windows11-home-dev_VARS.fd` from the host's OVMF Microsoft Secure Boot template. It grants the `libvirt-qemu` account access with ACLs. This file is host-specific and is recreated automatically after a host reinstall. Set `WIN11_NVRAM_PATH` or `WIN11_QEMU_USER` for a different host layout.

Set `WIN11_BOX_NAME` to test another registered box and `WIN11_HOSTNAME` to change the Windows hostname. Destroy the test VM with:

```bash
vagrant destroy -f
```
