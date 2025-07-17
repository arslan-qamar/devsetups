## Install or Uninstall kubectl CLI with Ansible

### Install kubectl

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="kubectl" -K
```

### Uninstall kubectl

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=absent" -t="kubectl" -K
```

- Requires sudo privileges for installation/removal.
- Downloads the latest stable kubectl binary for Linux amd64.
- Installs to `/usr/local/bin/kubectl`.
