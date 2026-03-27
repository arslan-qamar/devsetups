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
- Verifies the PostgreSQL service is running after installation.