resource "aws_security_group" "security_group" {
  name        = "ec2_security_group"
  description = "Security group for Jenkins EC2 instance"
  vpc_id      = var.vpc_id

  tags = {
    Name = "EC2-Jenkins-SG"
  }
}

# Inbound rules
resource "aws_security_group_rule" "allow_ssh" {
  security_group_id = aws_security_group.security_group.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # Consider restricting this to your IP
  description       = "Allow SSH from anywhere"
}

resource "aws_security_group_rule" "allow_jenkins" {
  security_group_id = aws_security_group.security_group.id
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # Consider restricting this
  description       = "Allow Jenkins web access"
}

# Outbound rule - allow all traffic
resource "aws_security_group_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.security_group.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}