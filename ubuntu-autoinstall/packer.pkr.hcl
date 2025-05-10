packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.4"
      source  = "github.com/hashicorp/virtualbox"
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

variable "ubuntu_password" {
  type    = string
  default = "$6$Y6IBLDCYg63Nffd7$JBncCo.DKEEtnu7kdCmSue8NG/HzOu/b2jftRzLGLoSyR1C8UIzlvpVIykjdv454x1lYSm5bqYWMR2N85KSAS/"
}

source "virtualbox-iso" "ubuntu" {
  guest_os_type    = "Ubuntu_64"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum  
  keep_registered = true

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_private_key_file = "~/.ssh/vagrant_custom_key"
  ssh_timeout  = "20m"

  cpus       = 8
  memory     = 4096
  disk_size  = 50240

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "VMSVGA"],
    ["modifyvm", "{{.Name}}", "--firmware", "efi"],
    ["modifyvm", "{{.Name}}", "--vram", "128"]
  ]

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
  sources = ["source.virtualbox-iso.ubuntu"]


  post-processor "vagrant" {
    output = "output/ubuntu-dev.box"
  }
}
