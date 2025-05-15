#creation of the public subenets
resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name = "public-subnet-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name = "public-subnet-2"
    "kubernetes.io/role/elb" = "1"
  }
}
