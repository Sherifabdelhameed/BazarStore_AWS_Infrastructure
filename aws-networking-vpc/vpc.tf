#bn3raf al vpc beta3tna 
resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr

  tags = {
    Name = "My-VPC"
  }
}