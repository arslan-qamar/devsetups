## Oracle Cloud Infrastructure CLI

This role installs the OCI CLI on Ubuntu/Debian hosts using Oracle's official install script. It places the CLI under `/opt/oracle/oci-cli`, exposes `oci` in `/usr/local/bin`, and supports `state=absent` to remove those role-managed paths. The role installs `curl` and Python 3 when needed; it does not remove these shared prerequisites.

```shell
ansible-playbook -vvv main.yml -i "localhost," --connection=local --extra-vars "state=present" -t=ocicli -K
```

The installer does not configure an account. Run `oci setup config` and provide the appropriate API signing key and endpoint settings. For Private Cloud Appliance, follow Oracle's PCA-specific configuration steps, including adding the appliance certificate. Credentials and certificate material are not managed by this role.

Install source: [Oracle PCA: Installing the OCI CLI](https://docs.oracle.com/en-us/iaas/private-cloud-appliance/pca/installing-the-oci-cli.htm).
