## Run the following command to install argocd CLI (Requires SUDO)

```shell
ansible-playbook -vvv main.yml -i "localhost" --connection="localhost" --extra-vars "state=present" -t="argocd" -K
```