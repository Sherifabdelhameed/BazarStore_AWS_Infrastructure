module "networking" {
  source   = "./aws-networking-vpc"
  vpc_cidr = "10.0.0.0/16"
  region = var.region

  
  
}


variable "region" {
    type = string
  
}