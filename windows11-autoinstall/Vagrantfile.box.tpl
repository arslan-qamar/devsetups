require "fileutils"
require "etc"

shared_folder_disabled = %w[1 true yes on].include?(
  ENV.fetch("VAGRANT_SHARED_DISABLED", "").downcase
)
shared_folder_password = ENV.fetch("VAGRANT_SHARED_SMB_PASSWORD", "")
shared_folder_user = ENV.fetch(
  "VAGRANT_SHARED_SMB_USER",
  Etc.getlogin || ENV.fetch("USER")
)

if !shared_folder_disabled && shared_folder_password.empty? &&
   ENV["DEVSETUPS_SHARED_FOLDER_NOTICE"] != "1"
  warn "[devsetups] VAGRANT_SHARED_SMB_PASSWORD is not set; skipping the optional VM shared folder."
  ENV["DEVSETUPS_SHARED_FOLDER_NOTICE"] = "1"
end

nvram_path = ENV.fetch(
  "WIN11_NVRAM_PATH",
  File.expand_path(".vagrant/windows11-home-dev_VARS.fd", Dir.pwd)
)
nvram_template = "/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
qemu_user = ENV.fetch("WIN11_QEMU_USER", "libvirt-qemu")

raise "Missing OVMF variables template: #{nvram_template}" unless File.file?(nvram_template)
setfacl_available = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
  File.executable?(File.join(directory, "setfacl"))
end
raise "Missing required host command: setfacl" unless setfacl_available
raise "Missing libvirt QEMU account: #{qemu_user}" unless system("id", qemu_user, out: File::NULL, err: File::NULL)

unless File.file?(nvram_path)
  FileUtils.mkdir_p(File.dirname(nvram_path))
  FileUtils.cp(nvram_template, nvram_path)
  FileUtils.chmod(0o600, nvram_path)
end

parent = File.dirname(nvram_path)
until parent == "/"
  system("setfacl", "-m", "u:#{qemu_user}:--x", parent) if File.owned?(parent)
  parent = File.dirname(parent)
end
raise "Unable to grant #{qemu_user} access to #{nvram_path}" unless system(
  "setfacl", "-m", "u:#{qemu_user}:rw-", nvram_path
)

Vagrant.configure("2") do |config|
  config.vm.guest = :windows
  config.vm.communicator = "winssh"
  config.vm.boot_timeout = 1800

  # vagrant-libvirt obtains connection credentials from config.ssh even when
  # the selected communicator is WinSSH. The communicator itself reads its
  # behavior from config.winssh, so keep the shared values in both sections.
  config.ssh.username = "vagrant"
  config.ssh.password = "__PASSWORD__"
  config.ssh.insert_key = false
  config.ssh.connect_timeout = 600

  config.winssh.username = "vagrant"
  config.winssh.password = "__PASSWORD__"
  config.winssh.insert_key = false
  config.winssh.connect_timeout = 600
  config.winssh.shell = "powershell"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  unless shared_folder_disabled || shared_folder_password.empty? ||
         ENV["DEVSETUPS_WINDOWS_SHARED_FOLDER_CONFIGURED"] == "1"
    config.vm.provision "shell",
                        name: "mount_vm_shared_folder",
                        run: "always",
                        privileged: false,
                        sensitive: true,
                        env: {
                          "VM_SHARED_DRIVE" => ENV.fetch("VAGRANT_SHARED_WINDOWS_DRIVE", "S:"),
                          "VM_SHARED_HOST" => ENV.fetch("VAGRANT_SHARED_SMB_HOST", ""),
                          "VM_SHARED_NAME" => ENV.fetch("VAGRANT_SHARED_SMB_NAME", "vagrant-shared"),
                          "VM_SHARED_USER" => shared_folder_user,
                          "VM_SHARED_PASSWORD" => shared_folder_password
                        },
                        inline: <<~'POWERSHELL'
                          $ErrorActionPreference = 'Stop'
                          if ([string]::IsNullOrWhiteSpace($env:VM_SHARED_HOST)) {
                              $env:VM_SHARED_HOST = ($env:SSH_CONNECTION -split '\s+')[0]
                          }
                          $remotePath = "\\$($env:VM_SHARED_HOST)\$($env:VM_SHARED_NAME)"
                          $client = [System.Net.Sockets.TcpClient]::new()
                          try {
                              $connection = $client.BeginConnect($env:VM_SHARED_HOST, 445, $null, $null)
                              if (-not $connection.AsyncWaitHandle.WaitOne(3000)) {
                                  Write-Warning 'Optional SMB share is unreachable on TCP 445; continuing provisioning.'
                                  exit 0
                              }
                              $client.EndConnect($connection)
                          }
                          catch {
                              Write-Warning 'Optional SMB share is unreachable on TCP 445; continuing provisioning.'
                              exit 0
                          }
                          finally {
                              $client.Dispose()
                          }
                          $existing = Get-SmbMapping -LocalPath $env:VM_SHARED_DRIVE -ErrorAction SilentlyContinue

                          if ($null -ne $existing -and
                              $existing.RemotePath -eq $remotePath -and
                              $existing.Status -eq 'OK') {
                              Write-Host "Shared folder is already mapped at $($env:VM_SHARED_DRIVE)"
                              exit 0
                          }
                          if ($null -ne $existing) {
                              Remove-SmbMapping -LocalPath $env:VM_SHARED_DRIVE -Force -UpdateProfile
                          }
                          $mappingOutput = & net.exe use `
                              $env:VM_SHARED_DRIVE `
                              $remotePath `
                              $env:VM_SHARED_PASSWORD `
                              "/user:$($env:VM_SHARED_USER)" `
                              /persistent:yes 2>&1

                          if ($LASTEXITCODE -ne 0) {
                              Write-Warning "Could not map the optional SMB share (net use exit $LASTEXITCODE); continuing provisioning."
                              exit 0
                          }
                          Write-Host "Mapped the shared host folder to $($env:VM_SHARED_DRIVE)"
                        POWERSHELL
    ENV["DEVSETUPS_WINDOWS_SHARED_FOLDER_CONFIGURED"] = "1"
  end

  config.vm.provider "libvirt" do |libvirt|
    libvirt.memory = 8192
    libvirt.cpus = 4
    libvirt.machine_type = "q35"
    libvirt.cpu_mode = "host-passthrough"
    libvirt.loader = "/usr/share/OVMF/OVMF_CODE_4M.ms.fd"
    libvirt.nvram = nvram_path
    libvirt.tpm_model = "tpm-crb"
    libvirt.tpm_type = "emulator"
    libvirt.tpm_version = "2.0"
    libvirt.disk_bus = "sata"
    libvirt.nic_model_type = "e1000"
    libvirt.graphics_type = "spice"
    libvirt.video_type = "virtio"
    libvirt.video_vram = 65536
    libvirt.channel type: "spicevmc",
                    target_type: "virtio",
                    target_name: "com.redhat.spice.0"
  end
end
