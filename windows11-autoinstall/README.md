# Windows 11 Home libvirt base box

This is the Windows counterpart to `ubuntu-autoinstall/`: Packer performs one unattended installation, generalizes Windows with Sysprep, and packages a reusable libvirt Vagrant box. The answer file selects **image 1, Windows 11 Home**, from the local Windows 11 24H2 English International ISO. It does not provide a product key or activate Windows. This retail ISO still asks for a key during Setup, so Packer selects **I don't have a product key** over the virtual keyboard after the page loads.

## Build

Host requirements: Packer, Vagrant with `vagrant-libvirt`, QEMU/KVM, OVMF Secure Boot firmware, `swtpm`, and `xorriso`. When a no-prompt installer ISO must be generated on an apt-based host, the bootstrap script automatically installs `p7zip-full` and `genisoimage` with `sudo`. The build defaults to the ISO already present at `/home/arslan/setups/Win11_24H2_EnglishInternational_x64.iso`. Set `WIN11_ISO_PATH` to build from a different ISO, and verify that its image 1 is Windows 11 Home before using it. The script caches a no-prompt copy of the ISO so Packer can boot Setup without a timed key press.

Each Vagrant project automatically creates writable UEFI variables under its `.vagrant` directory from the host's OVMF Microsoft Secure Boot template. The embedded Vagrantfile grants `libvirt-qemu` access using `setfacl`, so the NVRAM is recreated after a host reinstall. Set `WIN11_NVRAM_PATH` or `WIN11_QEMU_USER` for a different host layout.

```bash
cd windows11-autoinstall
./bootstrap.sh
```

The script verifies the ISO checksum, downloads and verifies the pinned official virtio-win Guest Tools installer, runs Packer, writes timestamped artifacts such as `output/windows11-home-dev-20260919-143000.box` and `output/windows11-home-dev-20260919-143000.json`, and registers the stable `windows11-home-dev` box name. Timestamped filenames preserve earlier build artifacts. Generated answer files, downloaded installers, and box output are ignored by Git. The local administrator credentials default to `vagrant` / `vagrant`, matching conventional development boxes. Set `WIN11_PASSWORD` before running the build to use another password.

Windows 11 24H2 can automatically encrypt the OS volume when TPM and Secure Boot are available. The installation and Sysprep answer files disable automatic device encryption, and the final preparation task verifies that `C:` is fully decrypted before Sysprep. This prevents cloned VMs from depending on the build VM's discarded TPM state. The preparation task also removes the ISO's user-installed Copilot package before Sysprep, avoiding the `0x80073cf2` package mismatch observed on the first test build.

Sysprep uses the generated `SysprepUnattend.xml` explicitly when generalizing the box. On the first boot of each clone, it supplies the locale, keyboard, generated computer name, timezone, network profile, OOBE suppression settings, and the existing `vagrant` account credentials. A clone reaches the desktop without asking for region, keyboard, device name, or another user account.

OpenSSH remains stopped while the clone processes `specialize` and OOBE. A one-time automatic login runs `complete-oobe.ps1`, removes the automatic-login registry credentials, and starts OpenSSH. Vagrant therefore cannot mistake an early setup-stage SSH connection for a completed boot. The embedded Vagrantfile also allows up to 30 minutes for the first boot and disables Vagrant's temporary public-key insertion. Connection credentials are set under both `config.ssh`, which `vagrant-libvirt` uses to build connection information, and `config.winssh`, which the WinSSH communicator uses.

The final preparation task installs virtio-win Guest Tools silently as Local System. The bundle provides the Windows 11 virtio GPU driver and SPICE agent. Consumer VMs use a virtio display with 64 MB of video memory and an explicit SPICE agent channel, avoiding the sluggish pointer behavior of QXL. In virt-manager, enable **View → Scale Display → Auto resize VM with window** to make the Windows resolution follow the console window. The guest tools also provide shared clipboard and improved pointer integration.

Boxes built before this encryption safeguard must be rebuilt; changing only the consumer Vagrantfile cannot decrypt an existing base image. If a future build fails during preparation or Sysprep, run `WIN11_PACKER_ON_ERROR=abort ./bootstrap.sh` to keep the VM and disk for inspection. In Windows, check `C:\Windows\Temp\prepare-vagrant-box.log` and `C:\Windows\System32\Sysprep\Panther\setuperr.log` for the exact failure. A preserved `output-windows11` directory must be moved aside before starting another build.

To test a fresh clone:

```bash
cd example
vagrant up --provider=libvirt
vagrant winssh -c 'Get-ComputerInfo | Select-Object WindowsProductName'
```

The Vagrant box carries Windows-specific WinSSH, UEFI, TPM, and libvirt settings. It intentionally does not load the Ubuntu `VagrantBaseFile` or Linux guest provisioners. The default VM hardware uses SATA and an emulated Intel network adapter so Setup does not depend on separate VirtIO drivers. The guest uses password-authenticated OpenSSH over the local libvirt network. Windows activation remains the responsibility of each VM user.

Optional build settings: `WIN11_BOX_NAME`, `WIN11_BOX_VERSION`, `WIN11_PASSWORD`, `WIN11_CPUS`, `WIN11_MEMORY_MB`, `WIN11_DISK_MB`, `WIN11_PACKER_ON_ERROR` (`cleanup` or `abort`), `WIN11_VIRTIO_GUEST_TOOLS_URL`, and `WIN11_VIRTIO_GUEST_TOOLS_SHA256`.
