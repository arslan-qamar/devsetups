## Install or Uninstall Postman with Ansible

### Install Postman

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present" -t="postman" -K
```

- Downloads the latest official Postman Linux archive for the current CPU architecture.
- Installs Postman under `/opt/Postman`.
- Creates a CLI launcher at `/usr/local/bin/postman`.
- Creates a desktop launcher at `/usr/share/applications/postman.desktop`.

### Uninstall Postman

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=absent" -t="postman" -K
```

- Removes the Postman desktop launcher, CLI symlink, installation directory, and downloaded archive.