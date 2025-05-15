#!/bin/bash
set -euo pipefail

# Configuration variables
CLUSTER_NAME="My-eks-cluster"
REGION="eu-north-1"
NAMESPACE="kube-system"
TEST_NAMESPACE="nginx-test"
ACCOUNT_ID="537124967157"
MANIFEST_DIR="k8s_test_manifest"

# Get values from Terraform outputs
SG_ID=$(terraform output -raw alb_security_group_id)
SUBNET_LIST=$(terraform output -raw public_subnets_csv)
VPC_ID=$(terraform output -raw vpc_id)

echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Verifying cluster access..."
kubectl get nodes

echo "Creating test namespace..."
kubectl create ns "$TEST_NAMESPACE" 2>/dev/null || true

# Prepare ingress manifest with security group and subnet IDs
echo "Updating ingress manifest with security group and subnet IDs..."
if [ -f "${MANIFEST_DIR}/ingress.yaml" ]; then
  cp "${MANIFEST_DIR}/ingress.yaml" "${MANIFEST_DIR}/ingress.yaml.bak"
  
  # Replace SG_ID placeholder
  sed -i "s/\${SG_ID}/$SG_ID/" "${MANIFEST_DIR}/ingress.yaml"
  
  # Replace SUBNET_LIST placeholder
  sed -i "s/\${SUBNET_LIST}/$SUBNET_LIST/" "${MANIFEST_DIR}/ingress.yaml"
  
  echo "Updated ingress manifest with security group ID: $SG_ID"
  echo "Updated ingress manifest with subnet list: $SUBNET_LIST"
else
  echo "WARNING: ${MANIFEST_DIR}/ingress.yaml not found"
fi

echo "EKS Cluster is ready to host applications"
echo "----------------------------------------"
echo "Manual deployment commands:"
echo "kubectl apply -f ${MANIFEST_DIR}/namespace.yaml"
echo "kubectl apply -f ${MANIFEST_DIR}/deployment.yaml -n $TEST_NAMESPACE"
echo "kubectl apply -f ${MANIFEST_DIR}/service.yaml -n $TEST_NAMESPACE"  
echo "kubectl apply -f ${MANIFEST_DIR}/ingress.yaml -n $TEST_NAMESPACE"
echo "----------------------------------------"
echo "Setup completed successfully!"