## Install or Uninstall PostgreSQL with Ansible

### Install PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present" -t="postgres" -K
```

### Uninstall PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=absent" -t="postgres" -K
```

- Installs `postgresql` from the Ubuntu apt repositories, matching the Ubuntu Server PostgreSQL setup guide.
- Creates a default `main` cluster if package installation does not create one automatically.
- Starts PostgreSQL and verifies that at least one PostgreSQL cluster is `online` via `pg_lsclusters`.
- Verifies the local database is reachable with `psql template1 -c "SELECT 1;"` as the `postgres` user.
- Removes PostgreSQL server packages for `state=absent` without purging data, and verifies existing data directories under `/var/lib/postgresql` remain intact.