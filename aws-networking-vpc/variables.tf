#variables for passing different parameters - reusability
variable "vpc_cidr" {
    type = string
}

variable "region" {
  type = string
  default = "eu-north-1"
}