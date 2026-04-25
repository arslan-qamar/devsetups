## Install or Uninstall MongoDB Compass with Ansible

### Install MongoDB Compass

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=present" -t="mongodb_compass" -K
```

- Downloads the official MongoDB Compass `.deb` package for Ubuntu 64-bit.
- Installs the `mongodb-compass` package.
- Defaults to MongoDB Compass `1.49.4`; override with `mongodb_compass_version`.

### Uninstall MongoDB Compass

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection="local" --extra-vars "state=absent" -t="mongodb_compass" -K
```

- Removes the `mongodb-compass` package and temporary installer file.
