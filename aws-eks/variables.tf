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
}

variable "jenkins_role_arn" {
    type = string
    description = "The ARN of the Jenkins IAM role to grant EKS cluster access"
    default = "arn:aws:iam::537124967157:role/jenkins-deployment-role"
}