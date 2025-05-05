#outputs for variables to be accessed to other modules
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr" {
  description = "The CIDR of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "public_subnet1_id" {
  description = "The ID of public subnet 1"
  value       = aws_subnet.public-subnet1.id
}

output "public_subnet2_id" {
  description = "The ID of public subnet 2"
  value       = aws_subnet.public-subnet2.id
}

output "private_subnet1_id" {
  description = "The ID of private subnet 1"
  value       = aws_subnet.private-subnet1.id
}

output "private_subnet2_id" {
  description = "The ID of private subnet 2"
  value       = aws_subnet.private-subnet2.id
}