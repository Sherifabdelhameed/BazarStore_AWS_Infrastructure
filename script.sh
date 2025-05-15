#!/bin/bash
# filepath: /home/sherifabdelhameed/DEPI_Terraform_Project/script.sh
set -euo pipefail

CLUSTER_NAME="My-eks-cluster"
REGION="eu-north-1"
NAMESPACE="kube-system"
SERVICE_ACCOUNT="aws-load-balancer-controller"
ROLE_NAME="eks-alb-controller-role"
TEST_NAMESPACE="nginx-test"
ACCOUNT_ID="537124967157"

echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Checking current cluster nodes..."
kubectl get nodes

# Use eksctl to create identity mappings (more reliable than kubectl for RBAC)
echo "Setting up cluster admin access through eksctl identity mappings..."
eksctl create iamidentitymapping \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --arn "arn:aws:iam::$ACCOUNT_ID:user/SherifAbdelhameed" \
  --username "sherif" \
  --group "system:masters" || echo "Identity mapping for SherifAbdelhameed exists"

eksctl create iamidentitymapping \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --arn "arn:aws:iam::$ACCOUNT_ID:user/YoussefAshraf" \
  --username "youssef" \
  --group "system:masters" || echo "Identity mapping for YoussefAshraf exists"

eksctl create iamidentitymapping \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --arn "arn:aws:iam::$ACCOUNT_ID:user/Terraform" \
  --username "terraform" \
  --group "system:masters" || echo "Identity mapping for Terraform exists"

echo "Waiting 10 seconds for identity mappings to propagate..."
sleep 10

echo "Creating Kubernetes service account with existing IAM role..."
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text)
echo "Using existing IAM role: $ROLE_ARN"

kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" 2>/dev/null || echo "Service account already exists"
kubectl annotate serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" "eks.amazonaws.com/role-arn=$ROLE_ARN" --overwrite

echo "Adding Helm repo and updating..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "Installing AWS Load Balancer Controller CRDs..."
# Download CRDs locally to avoid GitHub fetch issues
curl -s -o crds.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/helm/aws-load-balancer-controller/crds/crds.yaml
kubectl apply -f crds.yaml || {
  echo "Failed to apply CRDs directly, trying eksctl..."
  eksctl utils install-aws-load-balancer-controller \
    --cluster="$CLUSTER_NAME" \
    --region="$REGION" \
    --approve
  exit 0
}

echo "Fetching VPC ID..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=My-VPC" --query "Vpcs[0].VpcId" --output text)
if [[ -z "$VPC_ID" ]]; then
  echo "Error: Could not find VPC with tag Name=My-VPC"
  exit 1
fi
echo "Using VPC ID: $VPC_ID"

echo "Installing AWS Load Balancer Controller using Helm..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n "$NAMESPACE" \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name="$SERVICE_ACCOUNT" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set enableCRDs=false

echo "Verifying controller deployment..."
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller