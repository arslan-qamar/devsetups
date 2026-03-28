## Install or Uninstall PostgreSQL with Ansible

### Install PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="postgres" -K
```

### Uninstall PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=absent" -t="postgres" -K
```

- Installs `postgresql` and `postgresql-contrib` from the Ubuntu apt repositories.
- Starts PostgreSQL and verifies that at least one PostgreSQL systemd unit is running after installation.
- Supports Ubuntu's versioned cluster units such as `postgresql@16-main.service`.