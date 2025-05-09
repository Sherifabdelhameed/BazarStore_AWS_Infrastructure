# Generate a key pair for EC2 SSH access
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Store private key locally for SSH access
resource "local_file" "jenkins_private_key" {
  content         = tls_private_key.jenkins_key.private_key_pem
  filename        = "${path.module}/jenkins_key.pem"
  file_permission = "0600"
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "ec2_key" {
  key_name   = "jenkins-deployer-key"
  public_key = tls_private_key.jenkins_key.public_key_openssh
}