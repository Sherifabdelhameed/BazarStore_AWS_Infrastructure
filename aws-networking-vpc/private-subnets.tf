#creation of the private subenets
resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "private-subnet-2"
  }
}

