module ProjectVM
  DEFAULT_TOOLS = %w[deps doppler helm argocd kubectl python docker githubcli zsh vscode dotnet rider microk8s].freeze

  def self.provision(config, repository: nil, tools: DEFAULT_TOOLS, git_signing:)
    root = File.expand_path('..', __dir__)
    guest_dir = '/home/ubuntu/.cache/devsetups/provisioning'
    config.ssh.forward_agent = true

    # Refresh the staged playbook on every provision, including edits to local roles.
    config.vm.provision 'shell', privileged: false, inline: "mkdir -p #{guest_dir}/roles"
    config.vm.provision 'file', source: File.join(root, 'main.yml'), destination: "#{guest_dir}/main.yml"
    config.vm.provision 'file', source: File.join(root, 'roles', '.'), destination: "#{guest_dir}/roles"

    config.vm.provision 'install_tools', type: 'ansible_local' do |ansible|
      ansible.provisioning_path = guest_dir
      ansible.playbook = 'main.yml'
      ansible.tags = tools
      ansible.extra_vars = { state: 'present', target_hosts: 'all' }
    end

    if repository
      config.vm.provision 'shell', name: 'checkout_project', privileged: false,
        env: { 'REPOSITORY_NAME' => repository },
        path: File.join(__dir__, 'checkout_project.sh')
    end

    if git_signing
      config.vm.provision 'shell', name: 'setup_git_signing', privileged: false,
        env: {
          'GIT_NAME' => ENV['GIT_NAME'],
          'GIT_EMAIL' => ENV['GIT_EMAIL'],
          'DOPPLER_SERVICE_TOKEN_GIT' => ENV['DOPPLER_SERVICE_TOKEN_GIT']
        },
        path: File.join(__dir__, 'setup_git_gpg_signing.sh')
      config.vm.provision 'shell', name: 'validate_setup', privileged: false,
        args: ['--forwarded-agent'], path: File.join(__dir__, 'provision_validate_setup.sh')
    end
  end
end
