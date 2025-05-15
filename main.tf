module "networking" {
  source   = "./aws-networking-vpc"
  vpc_cidr = "10.0.0.0/16"
  region   = var.region
}

module "aws-ec2" {
  source    = "./aws-ec2"
  ec2_ami   = "ami-0dd574ef87b79ac6c"
  ec2_type  = "t3.micro"
  subnet_id = module.networking.public_subnet2_id
  vpc_id    = module.networking.vpc_id
  vpc_cidr  = module.networking.vpc_cidr
}

module "aws-eks" {
  source                = "./aws-eks"
  az1                   = module.networking.private_subnet1_id
  az2                   = module.networking.private_subnet2_id
  vpc_id                = module.networking.vpc_id
  jenkins_role_arn      = module.aws-ec2.jenkins_role_arn
}
/*
module "aws-alb" {
  source          = "./aws-alb"
  vpc_id          = module.networking.vpc_id
  subnets_public = [module.networking.public_subnet1_id, module.networking.public_subnet2_id]
}
*/

variable "region" {
  type = string
}