#!/bin/bash
sudo amazon-linux-extras install -y java-openjdk11
sudo yum install -y git
sudo mkdir /opt/maven
cd /opt/maven
sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.1/binaries/apache-maven-3.9.1-bin.tar.gz
sudo tar -xvzf /opt/maven/apache-maven-3.9.1-bin.tar.gz
sudo mv apache-maven-3.9.1 maven39
sudo rm -rf apache-maven-3.9.1-bin.tar.gz
sudo sed -i '10d' /home/ec2-user/.bash_profile
sudo sed -i '8 aJAVA_HOME=/usr/lib/jvm/jre-11-openjdk-11.0.18.0.10-1.amzn2.0.1.x86_64\n\nM2_HOME=/opt/maven/maven39\n\nPATH=$HOME/.local/bin:$HOME/bin:$JAVA_HOME:$M2_HOME/bin:$PATH' /home/ec2-user/.bash_profile
/home/ec2-user/.bash_profile
sudo yum install -y wget

sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum install -y jenkins