packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = ">= 1.1.0"
    }
  }
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "box_name" {
  type    = string
  default = "windows11-home-dev"
}

variable "box_output_path" {
  type    = string
  default = "output/windows11-home-dev.box"
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 8192
}

variable "disk_size" {
  type    = number
  default = 81920
}

source "qemu" "windows11" {
  accelerator      = "kvm"
  vm_name          = "${var.box_name}.qcow2"
  output_directory = "output-windows11"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  format         = "qcow2"
  disk_size      = var.disk_size
  disk_interface = "ide"
  net_device     = "e1000"

  machine_type = "q35"
  cpu_model    = "host"
  cpus         = var.cpus
  memory       = var.memory

  efi_boot          = true
  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
  efi_drop_efivars  = true

  vtpm            = true
  tpm_device_type = "tpm-crb"

  headless = true

  # Setup requires an explicit "I don't have a product key" choice with this ISO.
  # The answer file selects Home; these keys activate the no-key link after Setup loads.
  boot_wait    = "1m"
  boot_command = ["<tab><enter>"]

  cd_files = [
    "generated/Autounattend.xml",
    "scripts/enable-ssh.ps1",
    "scripts/prepare-vagrant-box.ps1",
    "scripts/complete-oobe.ps1",
    "generated/SysprepUnattend.xml",
  ]
  cd_label = "PACKERCFG"

  communicator             = "ssh"
  ssh_username             = "vagrant"
  ssh_password             = var.ssh_password
  ssh_timeout              = "2h"
  ssh_file_transfer_method = "sftp"

  shutdown_command = "schtasks.exe /run /tn PrepareVagrantBox"
  # Preparation may need to decrypt an OS volume that 24H2 encrypted during OOBE.
  shutdown_timeout = "2h30m"
}

build {
  sources = ["source.qemu.windows11"]

  post-processor "vagrant" {
    provider_override    = "libvirt"
    vagrantfile_template = "generated/Vagrantfile.box"
    output               = var.box_output_path
  }
}
