## Run the following command to install HCP CLI (Requires SUDO)

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="microk8s" -K
```