# frozen_string_literal: true

require "etc"

module DevSetupsSharedFolder
  DEFAULT_LINUX_MOUNT = "/shared"
  DEFAULT_SMB_DRIVE = "S:"
  DEFAULT_SMB_SHARE = "vagrant-shared"

  def self.disabled?
    %w[1 true yes on].include?(ENV.fetch("VAGRANT_SHARED_DISABLED", "").downcase)
  end

  def self.credentials
    password = ENV.fetch("VAGRANT_SHARED_SMB_PASSWORD", "")
    username = ENV.fetch("VAGRANT_SHARED_SMB_USER", Etc.getlogin || ENV.fetch("USER"))
    [username, password]
  end

  def self.configured?
    _, password = credentials
    return true unless password.empty?

    unless ENV["DEVSETUPS_SHARED_FOLDER_NOTICE"] == "1"
      warn "[devsetups] VAGRANT_SHARED_SMB_PASSWORD is not set; skipping the optional VM shared folder."
      ENV["DEVSETUPS_SHARED_FOLDER_NOTICE"] = "1"
    end
    false
  end

  def self.shared_environment
    username, password = credentials
    {
      # An empty value tells the guest script to use the client address from
      # its active Vagrant SSH/WinSSH connection. An override remains useful
      # for nonstandard proxy or remote-libvirt setups.
      "VM_SHARED_HOST" => ENV.fetch("VAGRANT_SHARED_SMB_HOST", ""),
      "VM_SHARED_NAME" => ENV.fetch("VAGRANT_SHARED_SMB_NAME", DEFAULT_SMB_SHARE),
      "VM_SHARED_USER" => username,
      "VM_SHARED_PASSWORD" => password
    }
  end

  def self.configure_linux(config)
    return if disabled? || !configured?

    config.vm.provision "shell",
                        name: "mount_vm_shared_folder",
                        run: "always",
                        privileged: true,
                        sensitive: true,
                        env: shared_environment.merge(
                          "VM_SHARED_MOUNT" => ENV.fetch("VAGRANT_SHARED_LINUX_MOUNT", DEFAULT_LINUX_MOUNT),
                          "VM_SHARED_GUEST_USER" => "ubuntu"
                        ),
                        path: File.expand_path("mount_linux_shared_folder.sh", __dir__)
  end

  def self.configure_windows(config)
    return if disabled? || !configured? || ENV["DEVSETUPS_WINDOWS_SHARED_FOLDER_CONFIGURED"] == "1"

    config.vm.provision "shell",
                        name: "mount_vm_shared_folder",
                        run: "always",
                        privileged: false,
                        sensitive: true,
                        env: shared_environment.merge(
                          "VM_SHARED_DRIVE" => ENV.fetch("VAGRANT_SHARED_WINDOWS_DRIVE", DEFAULT_SMB_DRIVE),
                        ),
                        path: File.expand_path("mount_windows_shared_folder.ps1", __dir__)
    ENV["DEVSETUPS_WINDOWS_SHARED_FOLDER_CONFIGURED"] = "1"
  end
end
