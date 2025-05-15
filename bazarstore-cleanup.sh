#!/bin/bash
set -eo pipefail

PROD_NAMESPACE="bazarstore-prod"
CLUSTER_NAME="My-eks-cluster"
REGION="eu-north-1"

echo "Starting cleanup of BazarStore resources..."

# Make sure kubectl is configured
echo "Updating kubeconfig for EKS cluster..."
if ! aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME; then
  echo "Error updating kubeconfig. Check if cluster '$CLUSTER_NAME' exists in region '$REGION'."
  echo "To list available clusters: aws eks list-clusters --region $REGION"
  
  # If you want to proceed with other cleanup tasks that don't require kubectl
  echo "Continuing with AWS resource cleanup..."
else
  # Proceed with Kubernetes resource deletion
  echo "Kubeconfig updated successfully."
  
  # Delete ingress first to trigger ALB deletion
  echo "Deleting ingress resources..."
  kubectl delete ingress --all -n $PROD_NAMESPACE --ignore-not-found=true

  # Wait for ingress controller to start cleaning up resources
  echo "Waiting for ingress controller to clean up resources..."
  sleep 10

  # Delete services and deployments
  echo "Deleting services and deployments..."
  kubectl delete service --all -n $PROD_NAMESPACE --ignore-not-found=true
  kubectl delete deployment --all -n $PROD_NAMESPACE --ignore-not-found=true

  # Delete PVCs and PVs
  echo "Deleting persistent volumes and claims..."
  kubectl delete pvc --all -n $PROD_NAMESPACE --ignore-not-found=true
  kubectl delete pv postgres-pv-prod --ignore-not-found=true

  # Delete configmaps and secrets
  echo "Deleting configmaps and secrets..."
  kubectl delete configmap --all -n $PROD_NAMESPACE --ignore-not-found=true
  kubectl delete secret --all -n $PROD_NAMESPACE --ignore-not-found=true

  # Delete the namespace
  echo "Deleting namespace..."
  kubectl delete namespace $PROD_NAMESPACE --ignore-not-found=true

  # Wait for namespace termination
  echo "Checking for namespace termination..."
  if kubectl get namespace $PROD_NAMESPACE &>/dev/null; then
    echo "Namespace $PROD_NAMESPACE is still terminating, continuing with AWS resource cleanup..."
  else
    echo "Namespace terminated or not found."
  fi
fi

# Always perform AWS resource cleanup regardless of kubectl connectivity
echo "Finding and removing orphaned target groups..."
aws_target_groups=$(aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `k8s`)].[TargetGroupArn]' --output text 2>/dev/null) || aws_target_groups=""
if [ -n "$aws_target_groups" ]; then
  for tg in $aws_target_groups; do
    echo "Deleting target group $tg"
    aws elbv2 delete-target-group --target-group-arn $tg || true
  done
else
  echo "No relevant target groups found."
fi

echo "Finding and removing orphaned load balancers..."
aws_load_balancers=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].[LoadBalancerArn]' --output text 2>/dev/null) || aws_load_balancers=""
if [ -n "$aws_load_balancers" ]; then
  for lb in $aws_load_balancers; do
    echo "Deleting load balancer $lb"
    aws elbv2 delete-load-balancer --load-balancer-arn $lb || true
  done
  
  # Wait for load balancers to be deleted before attempting to delete network interfaces
  echo "Waiting for load balancers to be deleted..."
  sleep 30
else
  echo "No relevant load balancers found."
fi

# Check for orphaned network interfaces
echo "Checking for orphaned network interfaces..."
aws_network_interfaces=$(aws ec2 describe-network-interfaces --filters "Name=description,Values=*k8s-bazarstore-*,*ELB app/k8s*" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null) || aws_network_interfaces=""
if [ -n "$aws_network_interfaces" ]; then
  echo "Found orphaned network interfaces, attempting to delete..."
  for eni in $aws_network_interfaces; do
    echo "Processing ENI: $eni"
    
    # Check if ENI is attached
    attachment=$(aws ec2 describe-network-interfaces --network-interface-ids $eni --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null) || attachment=""
    
    if [ "$attachment" != "None" ] && [ -n "$attachment" ] && [ "$attachment" != "null" ]; then
      echo "Detaching ENI $eni (attachment $attachment)"
      aws ec2 detach-network-interface --attachment-id $attachment --force || true
      echo "Waiting for detachment to complete..."
      sleep 10
    fi
    
    echo "Deleting ENI $eni"
    aws ec2 delete-network-interface --network-interface-id $eni || echo "Failed to delete ENI $eni, may require manual cleanup"
  done
else
  echo "No orphaned network interfaces found."
fi

echo "BazarStore cleanup complete!"