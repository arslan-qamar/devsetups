packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }

    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "file:///media/arslan/Ubuntu Data/ISO/ubuntu-24.04.2-desktop-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:d7fe3d6a0419667d2f8eff12796996328daa2d4f90cd9f87aa9371b362f987bf"
}

variable "box_name" {
  type    = string
  default = "ubuntu-dev"
}

variable "cpus" {
  type    = number
  default = 10
}

variable "memory" {
  type    = number
  default = 8196 # 8GB
}

variable "disk_size" {
  type    = number
  default = 50240 # 50GB
}

source "qemu" "ubuntu" {
  accelerator      = "kvm"
  vm_name          = var.box_name
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_private_key_file = "./vagrant_custom_key"
  ssh_timeout  = "20m"

  cpus           = var.cpus
  memory         = var.memory
  disk_size      = var.disk_size
  format         = "qcow2"
  net_device     = "virtio-net"
  disk_interface = "virtio"

  boot_wait  = "10s"
  boot_command = [
    "c", "<wait3s>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud", "<enter><wait3s>",
    "initrd /casper/initrd", "<enter><wait3s>",
    "boot", "<enter>"
  ]

  cd_files  = ["./meta-data", "./user-data"]
  cd_label  = "cidata"

  headless  = false
}

build {
  sources = ["source.qemu.ubuntu"]

  post-processor "vagrant" {
    provider_override = "libvirt"
    output = "output/${var.box_name}.box"
  }
}
