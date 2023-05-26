resource "aws_security_group" "security_group" {
  name        = "SSH-HTTP Communication"
  description = "Allow inbound traffic to the Jenkins server"

  dynamic "ingress" {
    for_each = var.security_group
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port2
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name                = "my_sec_grp"
    LaunchedByTerraform = "True"
  }
}

resource "aws_key_pair" "my_key_pair" {
  depends_on = [aws_security_group.security_group]
  key_name   = "Linux_keyPair"
  public_key = file("${path.module}/mykeypair")

}

resource "aws_instance" "environement" {
  depends_on    = [aws_key_pair.my_key_pair]
  ami           = data.aws_ami.amz-ami-environement.id
  instance_type = count.index == 3 ? "t2.small" : "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name
  count         = 4
  tags = {
    "Name" = count.index == 0 ? "ansible_server" : count.index == 1 ? "jenkins_master" : count.index == 2 ? "jenkins_slave" : count.index == 3 ? "jfrog_artifactory" : "ansible_node"
  }
  availability_zone = "us-east-1e"
  security_groups   = [aws_security_group.security_group.name]
  user_data         = file("${path.module}/user_data.sh")
}

resource "local_file" "hosts" {
  filename = "${abspath(path.root)}/hosts"
  content  = "[localhost]\n${join("\n", [for instance in aws_instance.environement : instance.public_ip if instance.tags["Name"] == "ansible_server"])}\n\n[artifactory]\n${join("\n", [for instance in aws_instance.environement : instance.public_ip if instance.tags["Name"] == "jfrog_artifactory"])}\n\n[jenkins_master]\n${join("\n", [for instance in aws_instance.environement : instance.public_ip if instance.tags["Name"] == "jenkins_master"])}\n\n[jenkins_slave]\n${join("\n", [for instance in aws_instance.environement : instance.public_ip if instance.tags["Name"] == "jenkins_slave"])}\n\n[common]\n${join("\n", [for instance in aws_instance.environement : instance.public_ip])}"
}

resource "null_resource" "control" {
  depends_on = [local_file.hosts]
  triggers = {
    change = timestamp()
  }

  connection {
    agent       = false
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
    host        = element(aws_instance.environement.*.public_ip, 0)
    private_key = file("${path.module}/key.pem")
  }

  provisioner "file" {
    source      = "id_rsa"
    destination = "/home/ec2-user/id_rsa"
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "file" {
    source      = "control_node.sh"
    destination = "/home/ec2-user/control_node.sh"
  }

  provisioner "file" {
    source      = "hosts"
    destination = "/home/ec2-user/hosts"
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",
      "sudo hostnamectl set-hostname master",
      "sleep 60",
      "chmod 700 /home/ec2-user/control_node.sh",
      "bash -x /home/ec2-user/control_node.sh",
      "sudo mv /home/ec2-user/hosts /etc/ansible/",
      "sudo chown -R root: /etc/ansible/hosts",
      "sudo mkdir /home/ansadmin/.ssh",
      "sudo cp /home/ec2-user/id_rsa.pub /home/ansadmin/.ssh/authorized_keys",
      "sudo mv /home/ec2-user/id_rsa /home/ansadmin/.ssh/",
      "sudo mv /home/ec2-user/id_rsa.pub /home/ansadmin/.ssh/",
      "sudo chown -R ansadmin: /home/ansadmin/.ssh",
      "sudo chmod 700 /home/ansadmin/.ssh/",
      "sudo chmod 600 /home/ansadmin/.ssh/id_rsa",
      "sudo sed -i '72s/#//' /etc/ansible/ansible.cfg"
    ]
    on_failure = continue
  }
}

resource "null_resource" "slave" {
  depends_on = [aws_instance.environement]
  triggers = {
    change = timestamp()
  }
  count = length(aws_instance.environement) > 1 ? length(aws_instance.environement) - 1 : 0

  connection {
    agent       = false
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
    host        = element(aws_instance.environement.*.public_ip, count.index + 1)
    private_key = file("${path.module}/key.pem")
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname slave",
      "sleep 60",
      "sudo mkdir /home/ansadmin/.ssh/",
      "sudo mv /home/ec2-user/id_rsa.pub /home/ansadmin/.ssh/authorized_keys",
      "sudo chmod 600 /home/ansadmin/.ssh/authorized_keys",
      "sudo chown -R ansadmin:ansadmin /home/ansadmin/.ssh/"
    ]
    on_failure = continue
  }
}

resource "null_resource" "jenkins_master" {
  depends_on = [null_resource.control]
  triggers = {
    change = timestamp()
  }


  connection {
    agent       = false
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
    host        = element(aws_instance.environement.*.public_ip, 1)
    private_key = file("${path.module}/key.pem")
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "file" {
    source      = "jenkins_master.sh"
    destination = "/home/ec2-user/jenkins_master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/ec2-user/jenkins_master.sh",
      "bash -x /home/ec2-user/jenkins_master.sh",
      "sleep 120",
      "sudo systemctl enable --now jenkins"
    ]

    on_failure = continue
  }
}

resource "null_resource" "jenkins_slaves" {
  depends_on = [null_resource.control]
  triggers = {
    change = timestamp()
  }

  connection {
    agent       = false
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
    host        = element(aws_instance.environement.*.public_ip, 2)
    private_key = file("${path.module}/key.pem")
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "file" {
    source      = "jenkins_slaves.sh"
    destination = "/home/ec2-user/jenkins_slaves.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/ec2-user/jenkins_slaves.sh",
      "bash -x /home/ec2-user/jenkins_slaves.sh",
    ]
    on_failure = continue
  }
}

resource "null_resource" "artifactory" {
  depends_on = [null_resource.control]
  triggers = {
    change = timestamp()
  }

  connection {
    agent       = false
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
    host        = element(aws_instance.environement.*.public_ip, 3)
    private_key = file("${path.module}/key.pem")
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "file" {
    source      = "id_rsa.pub"
    destination = "/home/ec2-user/id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y java-openjdk11",
      "sudo wget https://jfrog.bintray.com/artifactory/jfrog-artifactory-oss-6.9.6.zip",
      "sudo unzip jfrog-artifactory-oss-6.9.6.zip",
      "sudo rm -rf jfrog-artifactory-oss-6.9.6.zip",
      "sleep 30",
      "sudo /home/ec2-user/artifactory-oss-6.9.6/bin/artifactory.sh start"
    ]
    on_failure = continue
  }

}
