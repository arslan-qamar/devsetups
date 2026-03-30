## Run the following command to install Node.js (Requires SUDO)

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="nodejs" -K
```

This role installs Node.js from the NodeSource repository instead of Ubuntu's default package. By default it tracks the current major line configured in `roles/nodejs/vars/main.yml`, which is set to Node.js 25.