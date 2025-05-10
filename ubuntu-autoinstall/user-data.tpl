#cloud-config
autoinstall:
  version: 1  
  identity:
    hostname: ubuntu-vm
    username: ubuntu
    password: "{{ ubuntu_password }}"
  ssh:
     install-server: yes
     allow-pw: no
     authorized-keys:
       - {{ ssh_authorized_key }}
  apt:
    fallback: offline-install   
  users:
    - name: ubuntu
      sudo: ALL=(ALL) NOPASSWD:ALL
      groups: sudo
      shell: /bin/bash
      ssh_authorized_keys:
        - {{ ssh_authorized_key }}
  late-commands:
      - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
      - chmod 0440 /target/etc/sudoers.d/ubuntu




