variable "az1" {
    type = string
}

variable "az2" {
    type = string
}

variable "vpc_id" {
    type = string
}

variable "alb_security_group_id" {
    type = string
    description = "Security group ID for the ALB"
}

variable "jenkins_role_arn" {
    type = string
}