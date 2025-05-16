#!/bin/bash
set -euo pipefail

# Configuration variables
CLUSTER_NAME="My-eks-cluster"
REGION="eu-north-1"
PROD_NAMESPACE="bazarstore-prod"

# Check if Terraform resources are ready
echo "Checking if Terraform ALB resources are ready..."
if ! terraform output -raw alb_security_group_id &>/dev/null; then
  echo "Error: Terraform ALB resources not found."
  echo "Please run 'terraform apply' first and ensure it completes successfully."
  exit 1
fi

# Get values from Terraform outputs
SG_ID=$(terraform output -raw alb_security_group_id)
SUBNET_LIST=$(terraform output -raw public_subnets_csv)
VPC_ID=$(terraform output -raw vpc_id)

# Add after getting values from Terraform outputs
echo "Ensuring security group rules allow ALB to EKS node traffic..."

# Get the node security group ID
NODE_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

# Allow traffic from ALB security group to all node ports
aws ec2 authorize-security-group-ingress \
  --group-id $NODE_SG \
  --protocol tcp \
  --port 30000-32767 \
  --source-group $SG_ID 2>/dev/null || echo "Security group rule already exists"

echo "===== BazarStore Production Deployment ====="
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Verifying cluster access..."
kubectl get nodes || { echo "Failed to connect to EKS cluster"; exit 1; }

# Fix IAM permission for ALB controller
echo "Adding missing IAM permission for Load Balancer Controller..."
cat > /tmp/alb-policy-fix.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy --role-name eks-alb-controller-role --policy-name ModifyLBAttributesPolicy --policy-document file:///tmp/alb-policy-fix.json
echo "Restarting AWS Load Balancer Controller to apply new permissions..."
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Wait for AWS Load Balancer Controller pods to be ready before proceeding
echo "Waiting for AWS Load Balancer Controller pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=180s || {
  echo "Timed out waiting for AWS Load Balancer Controller pods to be ready."
  echo "Checking controller pod status..."
  kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  echo "Checking controller logs..."
  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  exit 1
}

echo "Checking if Sealed Secrets controller is installed..."
if ! kubectl get deployment sealed-secrets-controller -n kube-system &>/dev/null; then
  echo "Installing Sealed Secrets controller..."
  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
  helm repo update
  helm install sealed-secrets-controller sealed-secrets/sealed-secrets -n kube-system
  
  # Wait for controller to be ready
  kubectl wait --for=condition=available --timeout=90s deployment/sealed-secrets-controller -n kube-system
else
  echo "Sealed Secrets controller already installed, skipping..."
fi

# Wait for the controller to be ready
kubectl wait --for=condition=available --timeout=90s deployment/sealed-secrets-controller -n kube-system

# Step 1: Create Production Namespace
echo -e "\n1. Creating Production Namespace..."
kubectl apply -f prod/namespace/prod_namespace.yaml

# Define the password that all components will use
DB_PASSWORD="mysecretpassword"

# Step 2: Create ConfigMaps for database connections with the correct password
echo -e "\n2. Creating/Updating ConfigMaps..."
cat > /tmp/bazarstore-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: bazarstore-config
  namespace: ${PROD_NAMESPACE}
  labels:
    environment: production
data:
  catalog-db-url: "postgresql://postgres:${DB_PASSWORD}@postgres:5432/bazarcom"
  order-db-url: "postgresql://postgres:${DB_PASSWORD}@postgres:5432/bazarcom"
EOF

kubectl apply -f /tmp/bazarstore-configmap.yaml

# Step 3: Apply Sealed Secrets for database credentials
echo -e "\n3. Setting up Secrets..."
kubectl apply -f prod/secrets/sealed-secrets.yaml

# Handle the database credentials properly
echo "Checking if db-credentials secret exists..."
if ! kubectl get secret db-credentials -n ${PROD_NAMESPACE} &>/dev/null; then
  echo "Creating database credentials secret..."
  kubectl create secret generic db-credentials \
    --namespace ${PROD_NAMESPACE} \
    --from-literal=username=postgres \
    --from-literal=password=${DB_PASSWORD}
  echo "Secret created successfully."
else
  echo "Recreating the secret with consistent password..."
  kubectl delete secret db-credentials -n ${PROD_NAMESPACE}
  kubectl create secret generic db-credentials \
    --namespace ${PROD_NAMESPACE} \
    --from-literal=username=postgres \
    --from-literal=password=${DB_PASSWORD}
  echo "Secret recreated successfully."
fi

# Verify the connection strings in ConfigMap match the secret's password
echo "Verifying database connection configuration..."
kubectl get configmap bazarstore-config -n ${PROD_NAMESPACE} -o yaml

# Step 4: Clean up PostgreSQL storage to ensure fresh initialization with the correct password
echo -e "\n4. Cleaning up existing PostgreSQL storage..."
# Delete any existing deployments first to release the PVC
kubectl delete deployment postgres -n ${PROD_NAMESPACE} --ignore-not-found=true
# Delete PVC and PV to ensure fresh initialization with the new password
kubectl delete pvc postgres-pvc-prod -n ${PROD_NAMESPACE} --ignore-not-found=true
kubectl delete pv postgres-pv-prod --ignore-not-found=true

echo -e "\n4.1 Setting up PostgreSQL Persistent Volumes..."
kubectl apply -f prod/postgres/postgres-pv.yaml
kubectl apply -f prod/postgres/postgres-pvc.yaml

# Step 5: Deploy PostgreSQL Database
echo -e "\n5. Deploying PostgreSQL Database..."
kubectl apply -f prod/postgres/postgres-dep.yaml
kubectl apply -f prod/postgres/postgres-service.yaml

# Wait for PostgreSQL to be ready before deploying dependent services
echo "Waiting for PostgreSQL to be ready..."
kubectl rollout status deployment/postgres -n $PROD_NAMESPACE --timeout=180s

# Check PostgreSQL logs to verify it started correctly
echo "Checking PostgreSQL logs to verify startup..."
kubectl logs -n $PROD_NAMESPACE deployment/postgres --tail=20

# To:
echo "Ensuring database 'bazarcom' exists..."
PG_POD=$(kubectl get pod -l app=postgres -n $PROD_NAMESPACE -o jsonpath='{.items[0].metadata.name}')
# Fixed PostgreSQL command syntax for database creation - removed -it flags
kubectl exec $PG_POD -n $PROD_NAMESPACE -- psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='bazarcom'" | grep -q 1 || \
  kubectl exec $PG_POD -n $PROD_NAMESPACE -- psql -U postgres -c "CREATE DATABASE bazarcom;"

# Step 6: Deploy BazarStore Microservices
echo -e "\n6. Deploying BazarStore Microservices..."
echo "6.1 Deploying Catalog Service..."
kubectl apply -f prod/catalog/catalog-dep.yaml
kubectl apply -f prod/catalog/catalog-service.yaml  

echo "6.2 Deploying Order Service..."
kubectl apply -f prod/order/order-dep.yaml
kubectl apply -f prod/order/order-service.yaml

echo "6.3 Deploying Core Service..."
kubectl apply -f prod/core/core-dep.yaml
kubectl apply -f prod/core/core-service.yaml

# Wait for services to be ready
echo "Waiting for services to become ready..."
kubectl rollout status deployment/catalog -n $PROD_NAMESPACE --timeout=120s
kubectl rollout status deployment/order -n $PROD_NAMESPACE --timeout=120s
kubectl rollout status deployment/core -n $PROD_NAMESPACE --timeout=120s

# Step 7: Create ALB Ingress for BazarStore
echo -e "\n7. Creating ALB Ingress for BazarStore..."

cat > /tmp/bazarstore-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bazarstore-ingress
  namespace: ${PROD_NAMESPACE}
  labels:
    environment: production
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/security-groups: ${SG_ID}
    # Fix healthcheck paths to match actual health endpoints
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '20'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '10'
    alb.ingress.kubernetes.io/healthcheck-path-pattern: |
      /=/, /api/catalog=/api/catalog/health, /api/order=/api/order/health
    alb.ingress.kubernetes.io/success-codes: '200-399'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
    alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60,routing.http.drop_invalid_header_fields.enabled=true
    alb.ingress.kubernetes.io/tags: Environment=production,Application=bazarstore
    alb.ingress.kubernetes.io/subnets: ${SUBNET_LIST}
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: core
            port:
              number: 80
      - path: /api/catalog
        pathType: Prefix
        backend:
          service:
            name: catalog
            port:
              number: 5000
      - path: /api/order
        pathType: Prefix
        backend:
          service:
            name: order
            port:
              number: 5001
EOF

# Recreate the ingress to fix any previous issues
kubectl delete ingress bazarstore-ingress -n $PROD_NAMESPACE --ignore-not-found
kubectl apply -f /tmp/bazarstore-ingress.yaml

# Step 8: Verify deployment
echo -e "\n8. Verifying BazarStore Deployment..."

echo "8.1 Checking Pods Status..."
kubectl get pods -n $PROD_NAMESPACE

echo "8.2 Checking Services..."
kubectl get svc -n $PROD_NAMESPACE

echo "8.3 Checking Ingress..."
kubectl get ingress -n $PROD_NAMESPACE

# Wait for ALB to be provisioned
echo -e "\nWaiting for ALB to be provisioned (this may take several minutes)..."
sleep 30

# Fix the AWS CLI command syntax - remove the dot between 'elbv2' and 'describe'
for i in {1..20}; do
  ALB_ADDRESS=$(kubectl get ingress -n $PROD_NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  
  if [[ -n "$ALB_ADDRESS" ]]; then
    echo "ALB hostname found: $ALB_ADDRESS"
    
    # Just check the ALB directly without trying to extract the name
    echo "Verifying ALB existence in AWS..."
    if aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='$ALB_ADDRESS'].State.Code" --output text 2>/dev/null | grep -q "active"; then
      echo "✅ ALB is active and ready"
      break
    else
      echo "ALB found but not yet active. Waiting..."
    fi
  fi
  
  echo "Waiting for ALB address to be assigned and active... ($i/20)"
  sleep 15
done

if [[ -n "$ALB_ADDRESS" ]]; then
  echo -e "\n===== BazarStore Deployed Successfully! ====="
  echo "Access your BazarStore application at: http://${ALB_ADDRESS}"
  echo ""
  echo "API Endpoints:"
  echo "- Core UI:        http://${ALB_ADDRESS}/"
  echo "- Catalog API:    http://${ALB_ADDRESS}/api/catalog"
  echo "- Order API:      http://${ALB_ADDRESS}/api/order"
  echo ""
  echo "Note: It may take 2-3 minutes more for DNS to propagate fully."
  echo "If you get a DNS error, wait a few minutes and try again."
  
  # Step 9: Test BazarStore by adding a book
  echo -e "\n9. Testing BazarStore by adding a book..."
  echo "Waiting a moment for all services to be fully operational..."
  sleep 15
  
  # Create a test book using the catalog API
  echo "Adding test book..."
  BOOK_JSON='{
    "title": "Kubernetes in Production",
    "author": "Cloud Native Expert",
    "isbn": "978-1234567890",
    "category": "Distributed Systems",
    "price": 49.99,
    "inventory": 100,
    "description": "A comprehensive guide to running Kubernetes in production environments"
  }'
  
  # Try to add the book
  echo "Sending request to add book..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
    -d "$BOOK_JSON" "http://${ALB_ADDRESS}/api/catalog/books" || echo "000")
  
  HTTP_BODY=$(echo "$RESPONSE" | sed '$d')
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  
  if [[ "$HTTP_CODE" -ge 200 ]] && [[ "$HTTP_CODE" -lt 300 ]]; then
    echo "✅ Book created successfully!"
    echo "Response: $HTTP_BODY"
    
    # Extract book ID from response
    BOOK_ID=$(echo "$HTTP_BODY" | grep -o '"id":[0-9]*' | cut -d':' -f2 || echo "")
    
    if [[ -n "$BOOK_ID" ]]; then
      echo "Verifying book was created by retrieving it..."
      GET_RESPONSE=$(curl -s -w "\n%{http_code}" "http://${ALB_ADDRESS}/api/catalog/books/$BOOK_ID" || echo "000")
      GET_BODY=$(echo "$GET_RESPONSE" | sed '$d')
      GET_CODE=$(echo "$GET_RESPONSE" | tail -n1)
      
      if [[ "$GET_CODE" -ge 200 ]] && [[ "$GET_CODE" -lt 300 ]]; then
        echo "✅ Successfully retrieved book:"
        echo "$GET_BODY"
      else
        echo "❌ Failed to retrieve book. HTTP code: $GET_CODE"
      fi
    else
      echo "⚠️ Created book, but couldn't extract ID for verification"
    fi
  else
    echo "❌ Failed to create book. HTTP code: $HTTP_CODE"
    echo "Response: $HTTP_BODY"
    echo "Note: This could be because the catalog service needs more time to establish database connection"
  fi
else
  echo -e "\n===== BazarStore Deployment Issues ====="
  echo "ALB address not assigned. Troubleshooting:"
  echo "1. Check ingress status: kubectl get ingress -n ${PROD_NAMESPACE}"
  echo "2. Check controller logs: kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
  echo "3. Verify security groups: aws ec2 describe-security-groups --group-ids ${SG_ID}"
fi
echo -e "\nTo monitor your application:"
echo "kubectl get pods -n ${PROD_NAMESPACE} -w"
echo ""
echo "To clean up BazarStore resources, use ./bazarstore-cleanup.sh"