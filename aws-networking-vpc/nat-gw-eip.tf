#elastic public ip beta3 al NAT-GW
resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"
  
  # Instead, depend directly on the IGW
  depends_on = [aws_internet_gateway.gw]
}