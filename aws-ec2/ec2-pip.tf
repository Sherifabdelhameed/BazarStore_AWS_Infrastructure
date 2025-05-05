resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.EC2_network_interface.id
  associate_with_private_ip = "10.0.2.100"
}