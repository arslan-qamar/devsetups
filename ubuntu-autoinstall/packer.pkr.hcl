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
  default = "file:///media/arslan/Ubuntu Data/ISO/ubuntu-24.04.2-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
}

source "virtualbox-iso" "ubuntu" {
  guest_os_type    = "Ubuntu_64"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum  
  keep_registered = true

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  communicator = "ssh"
  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "20m"

  cpus       = 8
  memory     = 8096
  disk_size  = 50240

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--graphicscontroller", "vmsvga"],
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

  provisioner "shell" {
    name = "Install Minimal GNOME Desktop"
    inline = [      
      "echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf > /dev/null",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal",
      "sudo DEBIAN_FRONTEND=noninteractive systemctl set-default graphical.target",      
    ]
  }  

  post-processor "vagrant" {
    output = "output/ubuntu-dev.box"
  }
}
