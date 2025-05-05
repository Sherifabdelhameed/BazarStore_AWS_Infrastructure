module "networking" {
  source   = "./aws-networking-vpc"
  vpc_cidr = "10.0.0.0/16"
  public-subnets = ["public-subnet1", "public-subnet2"]
  
  
}


variable "region" {
    type = string
  
}