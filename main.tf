module "networking" {
  source   = "./aws-networking-vpc"
  vpc_cidr = "10.0.0.0/16"
  region   = var.region
}

module "aws-ec2" {
  source    = "./aws-ec2"
  ec2_ami   = "ami-04542995864e26699"
  ec2_type  = "t3.micro"
  subnet_id = module.networking.public_subnet2_id
  vpc_id    = module.networking.vpc_id
  vpc_cidr  = module.networking.vpc_cidr
}

module "aws-eks" {
  source = "./aws-eks"
  az1    = module.networking.private_subnet1_id
  az2    = module.networking.private_subnet2_id
  vpc_id = module.networking.vpc_id
  alb_security_group_id = module.aws-alb.alb_security_group_id
}

module "aws-alb" {
  source          = "./aws-alb"
  vpc_id          = module.networking.vpc_id
  subnets_private = [module.networking.public_subnet1_id, module.networking.public_subnet2_id]
}

variable "region" {
  type = string
}