#!/bin/bash

# Create necessary directories
mkdir -p test/ssh_keys

# Generate SSH keys
ssh-keygen -t rsa -b 4096 -f test/ssh_keys/id_rsa -N ""

# Create authorized_keys file
cat test/ssh_keys/id_rsa.pub > test/ssh_keys/authorized_keys

# Set proper permissions
chmod 700 test/ssh_keys
chmod 600 test/ssh_keys/id_rsa
chmod 644 test/ssh_keys/authorized_keys
chmod 644 test/ssh_keys/id_rsa.pub

# Create test inventory
cat > inventory/hosts.test.yml << EOF
all:
  children:
    jenkins:
      hosts:
        jenkins_server:
          ansible_host: localhost
          ansible_port: 2222
          ansible_user: root
          ansible_ssh_private_key_file: test/ssh_keys/id_rsa
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    
    eks_nodes:
      hosts:
        eks_node_1:
          ansible_host: localhost
          ansible_port: 2223
          ansible_user: root
          ansible_ssh_private_key_file: test/ssh_keys/id_rsa
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
        eks_node_2:
          ansible_host: localhost
          ansible_port: 2224
          ansible_user: root
          ansible_ssh_private_key_file: test/ssh_keys/id_rsa
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

# Create test variables
cat > group_vars/all.test.yml << EOF
---
# Test environment variables
jenkins_public_ip: "localhost"
eks_node_1_ip: "localhost"
eks_node_2_ip: "localhost"
jenkins_ssh_key: "test/ssh_keys/id_rsa"
eks_ssh_key: "test/ssh_keys/id_rsa"
jenkins_admin_password: "test123"

# Jenkins configuration
jenkins_version: "2.426.1.3"
jenkins_port: 8080
jenkins_admin_user: admin

# EKS node configuration
k8s_version: "1.28"
container_runtime: containerd
docker_version: "24.0.5"

# Common packages
common_packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - software-properties-common
  - gnupg
  - lsb-release

# AWS Configuration
aws_region: "eu-north-1"
EOF

echo "Test environment setup complete!"
echo "To start the containers, run: docker-compose up -d"
echo "To run Ansible playbook, use: ansible-playbook -i inventory/hosts.test.yml playbooks/site.yml" 