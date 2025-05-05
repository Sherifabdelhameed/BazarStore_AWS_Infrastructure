#elastic public ip beta3 al NAT-GW
resource "aws_eip" "nat-gw-eip" {
  domain   = "vpc"
}