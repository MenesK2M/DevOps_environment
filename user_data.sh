#!/bin/bash
sudo yum update -y
sudo yum install python3 -y
sudo sed -i '61s/#//; 63s/^/#/' /etc/ssh/sshd_config
sudo systemctl reload sshd

useradd -m -d /home/ansadmin -c "Ansible user controller" ansadmin
echo "test123" | passwd --stdin ansadmin
sed -i '110a\ansadmin ALL=(ALL) NOPASSWD: ALL' /etc/sudoers