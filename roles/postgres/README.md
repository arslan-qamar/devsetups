## Install or Uninstall PostgreSQL with Ansible

### Install PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present" -t="postgres" -K
```

By default, the role sets the `postgres` database user's password to `postgres`.

To set a password for the `postgres` database user during install:

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present postgres_password=your_password_here" -t="postgres" -K
```

To have Ansible prompt for the password when the playbook runs:

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present postgres_prompt_for_password=true" -t="postgres" -K
```

### Uninstall PostgreSQL

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=absent" -t="postgres" -K
```

- Installs `postgresql` from the Ubuntu apt repositories, matching the Ubuntu Server PostgreSQL setup guide.
- Installs `postgis`, `postgresql-postgis`, and the matching `postgresql-<version>-postgis-3` package for each detected PostgreSQL cluster version.
- Creates a default `main` cluster if package installation does not create one automatically.
- Starts PostgreSQL and verifies that at least one PostgreSQL cluster is `online` via `pg_lsclusters`.
- Verifies the local database is reachable with `psql template1 -c "SELECT 1;"` as the `postgres` user.
- Sets the `postgres` database user's password to `postgres` by default, or uses `postgres_password` / `postgres_prompt_for_password=true` when provided, then verifies password authentication over TCP.
- Removes PostgreSQL server packages for `state=absent` without purging data, and verifies existing data directories under `/var/lib/postgresql` remain intact.