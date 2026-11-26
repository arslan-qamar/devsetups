## Neon CLI

Install or remove the Neon CLI using the repository's `state` contract. The CLI is installed globally from npm as `neon`; Node.js and npm must be available, so install the `nodejs` role first (it is ordered before this role in `main.yml`).

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection=local --extra-vars "state=present" -t=neon -K
```

Use `state=absent` to remove the global npm package. Authentication and project linking are intentionally left to the user (`neon login` / `neon link`); the role does not create or store credentials.

Install source: [Neon CLI documentation](https://neon.com/docs/cli) (`npm i -g neon`).
