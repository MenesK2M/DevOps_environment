#!/bin/bash

sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker 
# add user to docker group 
sudo usermod -aG docker ansadmin

sudo mkdir /opt/docker
sudo chown -R ansadmin: /opt/docker

sudo yum install python3-pip -y

sudo amazon-linux-extras install ansible2 -y

sudo sed -i '10a\deprecation_warnings = false' /etc/ansible/ansible.cfg

sudo rm -rf /etc/ansible/hosts
