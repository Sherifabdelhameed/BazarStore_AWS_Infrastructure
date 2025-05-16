#!/bin/bash
set -e

echo "===== Ansible Connection & Deployment Script ====="

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
  echo "Error: Terraform doesn't appear to be initialized. Run 'terraform init' first."
  exit 1
fi

# Generate Ansible variables from Terraform outputs
echo "Step 1: Getting Terraform outputs for Ansible variables..."
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
if [ -z "$JENKINS_IP" ]; then
  echo "Error: Failed to get Jenkins public IP from terraform outputs."
  echo "Make sure you've applied your Terraform configuration first."
  exit 1
fi

KEY_PATH="$(pwd)/aws-ec2/jenkins_key.pem"
if [ ! -f "$KEY_PATH" ]; then
  echo "Error: Jenkins SSH key not found at $KEY_PATH"
  exit 1
fi

# Create or update ansible group_vars file
echo "Step 2: Generating Ansible variables..."
mkdir -p ansible/group_vars
cat > ansible/group_vars/all.yml << EOF
---
# Generated from Terraform outputs
jenkins_public_ip: "${JENKINS_IP}"
jenkins_ssh_key: "${KEY_PATH}"
eks_node_1_ip: "$(terraform output -raw eks_node_1_ip 2>/dev/null || echo 'to-be-determined')"
eks_node_2_ip: "$(terraform output -raw eks_node_2_ip 2>/dev/null || echo 'to-be-determined')"
eks_ssh_key: "${KEY_PATH}"  # Using same key for simplicity

# Other variables
jenkins_port: 8080
jenkins_admin_user: admin
jenkins_admin_password: "secure_password_here"  # Replace with your secure password

# AWS Configuration
aws_region: "$(terraform output -raw region 2>/dev/null || echo 'eu-north-1')"
EOF

echo "Ansible variables generated from Terraform outputs"

# Wait for SSH to be available on the Jenkins instance
echo "Step 3: Waiting for SSH to be available on Jenkins instance..."
for i in {1..30}; do
  echo "Attempting SSH connection ($i/30)..."
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_PATH" ubuntu@"$JENKINS_IP" 'echo "SSH connection successful"' &>/dev/null; then
    echo "✅ SSH connection established!"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "❌ Failed to establish SSH connection after 30 attempts."
    echo "Check if the instance is running and SSH port (22) is open."
    exit 1
  fi
  
  echo "Waiting for SSH service to start... (5s)"
  sleep 5
done

# Run Ansible playbook
echo "Step 4: Running Ansible to install prerequisites on Jenkins instance..."
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml || {
  echo "❌ Ansible playbook execution failed"
  exit 1
}

echo "===== Deployment Complete! ====="
echo "Jenkins is now configured at: http://$JENKINS_IP:8080"
echo "You can access the Jenkins UI with the credentials in ansible/group_vars/all.yml"