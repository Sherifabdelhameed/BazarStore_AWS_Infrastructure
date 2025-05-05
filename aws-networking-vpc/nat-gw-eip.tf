resource "aws_eip" "nat-gw-eip" {
  domain   = "vpc"
}