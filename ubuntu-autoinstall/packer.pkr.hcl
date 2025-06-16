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

source "virtualbox-iso" "ubuntu" {
  guest_os_type    = "Ubuntu_64"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum  
  keep_registered = true

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_private_key_file = "./vagrant_custom_key"
  ssh_timeout  = "20m"

  cpus       = var.cpus
  memory     = var.memory
  disk_size  = var.disk_size
  hard_drive_interface = "pcie"
  hard_drive_nonrotational = true


  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "VMSVGA"],
    ["modifyvm", "{{.Name}}", "--firmware", "efi"],
    ["modifyvm", "{{.Name}}", "--chipset", "ich9"],
    ["modifyvm", "{{.Name}}", "--vram", "128"],
    ["modifyvm", "{{.Name}}", "--accelerate-3d", "on"],
    ["modifyvm", "{{.Name}}", "--nested-paging", "on"],
    ["modifyvm", "{{.Name}}", "--nested-hw-virt", "on"],
    ["modifyvm", "{{.Name}}", "--hwvirtex", "on"],
    ["modifyvm", "{{.Name}}", "--clipboard-mode", "bidirectional"],
    ["modifyvm", "{{.Name}}", "--audio", "alsa"],
    ["modifyvm", "{{.Name}}", "--audiocontroller", "ac97"],
    ["modifyvm", "{{.Name}}", "--accelerate3d", "on"],
    ["modifyvm", "{{.Name}}", "--audioout", "on"],    
    ["modifyvm", "{{.Name}}", "--vrde", "off"],]

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
    output = "output/${var.box_name}.box"
  }
}
