resource "aws_instance" "ec2_jenkins_server" {
  ami           = var.ec2_ami
  instance_type = var.ec2_type

  network_interface {
    network_interface_id = aws_network_interface.EC2_network_interface.id
    device_index         = 0
  }

  tags = {
    Name = "My-EC2-Jenkins-server"
  }
}

resource "aws_network_interface" "EC2_network_interface" {
  subnet_id       = var.subnet_id
  private_ips     = ["10.0.2.100"]
  security_groups = [aws_security_group.security_group.id]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_key_pair" "ec2-key" {
  key_name   = "deployer-key"
  public_key = file("/home/sherifabdelhameed/.ssh/ec2-keypair.pub")

}