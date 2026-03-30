## Install Go (Requires SUDO)

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="go" -K
```

## Uninstall Go (Requires SUDO)

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=absent" -t="go" -K
```

This role installs the pinned upstream Go release configured in `roles/go/vars/main.yml`.

- Current pinned version: `1.23.0`
- Install path: `/usr/local/go`
- Symlinks created: `/usr/local/bin/go` and `/usr/local/bin/gofmt`
- The role removes Ubuntu's `golang-go` package during install so an older distro binary does not take precedence on `PATH`.