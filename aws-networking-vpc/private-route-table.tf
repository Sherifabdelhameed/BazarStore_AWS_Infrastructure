#creation of the private route tables
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  # Add this lifecycle block
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "Private-route-table"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
  
  # Add this lifecycle block
  lifecycle {
    create_before_destroy = true
  }
}

#association al route tables bel subnets al private
resource "aws_route_table_association" "subnet1_priv" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "subnet2_priv" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}
