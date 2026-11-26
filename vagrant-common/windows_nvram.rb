require "fileutils"

module WindowsNvram
  def self.prepare(nvram_path)
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

    # System libvirt runs QEMU as a separate account. Grant directory traversal and
    # access to this VM's writable UEFI variables without opening the files to all.
    parent = File.dirname(nvram_path)
    until parent == "/"
      system("setfacl", "-m", "u:#{qemu_user}:--x", parent) if File.owned?(parent)
      parent = File.dirname(parent)
    end
    raise "Unable to grant #{qemu_user} access to #{nvram_path}" unless system(
      "setfacl", "-m", "u:#{qemu_user}:rw-", nvram_path
    )
  end
end
