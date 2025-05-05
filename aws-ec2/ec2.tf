resource "aws_instance" "ec2_jenkins_server" {
  ami           = var.ec2_ami
  instance_type = var.ec2_type

  network_interface {
    network_interface_id = aws_network_interface.EC2_network_interface.id
    device_index         = 0
  }

  vpc_security_group_ids = [aws_security_group.security_group.id]

  tags = {
    Name = "My-EC2-Jenkins-server"
  }
}

resource "aws_network_interface" "EC2_network_interface" {
  subnet_id   = var.subnet_id
  private_ips = ["10.0.2.100"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_key_pair" "ec2-key" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}