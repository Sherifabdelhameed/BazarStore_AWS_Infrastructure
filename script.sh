#!/bin/bash
# filepath: /home/sherifabdelhameed/DEPI_Terraform_Project/script.sh
set -euo pipefail

# Configuration variables
CLUSTER_NAME="My-eks-cluster"
REGION="eu-north-1"
NAMESPACE="kube-system"
SERVICE_ACCOUNT="aws-load-balancer-controller"
ROLE_NAME="eks-alb-controller-role"
TEST_NAMESPACE="nginx-test"
ACCOUNT_ID="537124967157"

echo "Updating eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Verifying cluster access..."
kubectl get nodes

echo "Enforcing cluster-admin permissions..."
for USER in SherifAbdelhameed YoussefAshraf Terraform; do
    # Remove existing conflicting mappings
    eksctl delete iamidentitymapping \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --arn "arn:aws:iam::${ACCOUNT_ID}:user/$USER" \
        --all || true
    
    # Create fresh mapping with admin rights
    eksctl create iamidentitymapping \
        --cluster "$CLUSTER_NAME" \
        --region "$REGION" \
        --arn "arn:aws:iam::${ACCOUNT_ID}:user/$USER" \
        --username "${USER,,}" \
        --group "system:masters" \
        --no-duplicate-arns
done

echo "Creating Kubernetes service account..."
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)
kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" 2>/dev/null || true
kubectl annotate serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" "eks.amazonaws.com/role-arn=$ROLE_ARN" --overwrite

echo "Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install CRDs with explicit admin rights
kubectl create clusterrolebinding crd-install \
    --clusterrole=cluster-admin \
    --user="arn:aws:iam::${ACCOUNT_ID}:user/SherifAbdelhameed" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f https://github.com/aws/eks-charts/raw/master/stable/aws-load-balancer-controller/crds/crds.yaml

# Get VPC ID dynamically for the controller
echo "Finding VPC ID..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=My-VPC" --query "Vpcs[0].VpcId" --output text)
echo "Using VPC ID: $VPC_ID"

# Find the EKS node security group - try by tag name first
echo "Finding EKS node security group ID..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=eks-node-security-group" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" --output text)

# If not found by tag, try by group name
if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  echo "Security group not found by tag, trying by name..."
  SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=eks-node-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text)
fi

# Verify we found a security group
if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  echo "ERROR: Could not find EKS node security group. Check your Terraform configuration."
  exit 1
fi

echo "Using security group ID: $SG_ID for ingress"

# Ensure security group has required inbound rules
echo "Ensuring security group has required rules..."
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr "0.0.0.0/0" 2>/dev/null || true

# Use the actual SG_ID value in the ingress.yaml file
if [ -f "k8s_test/ingress.yaml" ]; then
  echo "Updating security group in ingress.yaml..."
  # First check if the file contains ${SG_ID} placeholder
  if grep -q '\${SG_ID}' "k8s_test/ingress.yaml"; then
    sed -i "s/alb.ingress.kubernetes.io\\/security-groups: \${SG_ID}/alb.ingress.kubernetes.io\\/security-groups: $SG_ID/" k8s_test/ingress.yaml
  else
    # If not using placeholder, try to update the actual value
    sed -i "s/alb.ingress.kubernetes.io\\/security-groups: .*/alb.ingress.kubernetes.io\\/security-groups: $SG_ID/" k8s_test/ingress.yaml
  fi
fi

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set enableCertManager=false

echo "Verifying deployment..."
kubectl -n "$NAMESPACE" rollout status deployment/aws-load-balancer-controller --timeout=180s

echo "Cleaning up temporary permissions..."
kubectl delete clusterrolebinding crd-install

echo "Creating test namespace..."
kubectl create ns "$TEST_NAMESPACE" 2>/dev/null || true

echo "EKS Cluster is now ready to host applications"
echo "Security group ID for ingress: $SG_ID"
echo "VPC ID: $VPC_ID"
echo "----------------------------------------"
echo "To deploy test application, run:"
echo "kubectl apply -f k8s_test/deployment.yaml -n $TEST_NAMESPACE"
echo "kubectl apply -f k8s_test/service.yaml -n $TEST_NAMESPACE"  
echo "kubectl apply -f k8s_test/ingress.yaml -n $TEST_NAMESPACE"
echo "----------------------------------------"
echo "Installation completed successfully!"