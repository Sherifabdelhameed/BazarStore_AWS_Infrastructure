module "networking" {
  source   = "./aws-networking-vpc"
  vpc_cidr = "10.0.0.0/16"
  region   = var.region
}

module "aws-ec2" {
  source    = "./aws-ec2"
  ec2_ami   = "ami-0dd574ef87b79ac6c"
  ec2_type  = "t3.micro"
  subnet_id = module.networking.public_subnet2_id
  vpc_id    = module.networking.vpc_id
  vpc_cidr  = module.networking.vpc_cidr
}

module "aws-eks" {
  source                    = "./aws-eks"
  az1                       = module.networking.private_subnet1_id
  az2                       = module.networking.private_subnet2_id
  vpc_id                    = module.networking.vpc_id
  jenkins_role_arn          = module.aws-ec2.jenkins_role_arn
  alb_security_group_id     = module.aws-alb.alb_security_group_id
  jenkins_security_group_id = module.aws-ec2.jenkins_security_group_id
}

# Uncommented ALB module - will create the security group for your ingress resources
module "aws-alb" {
  source         = "./aws-alb"
  vpc_id         = module.networking.vpc_id
  subnets_public = [module.networking.public_subnet1_id, module.networking.public_subnet2_id]
}

# Add module for EKS addons (only ALB controller)
module "aws-eks-addons" {
  source                  = "./aws-eks-addons"
  cluster_name            = module.aws-eks.cluster_name
  region                  = var.region
  vpc_id                  = module.networking.vpc_id
  alb_controller_role_arn = module.aws-eks.alb_controller_role_arn
  alb_security_group_id   = module.aws-alb.alb_security_group_id

  depends_on = [module.aws-eks]
}

variable "region" {
  type = string
}

resource "null_resource" "pre_destroy_cleanup" {
  triggers = {
    cluster_name = module.aws-eks.cluster_name
    region       = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Configure kubectl
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}
      
      # Delete kubernetes resources first
      kubectl delete ingress --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete service --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete deployment --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete pvc --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete pv postgres-pv-prod --ignore-not-found=true
      kubectl delete namespace bazarstore-prod --ignore-not-found=true
      
      # Wait for kubernetes resources to be deleted
      sleep 30
      
      # Delete any node groups first to ensure proper cluster deletion
      aws eks list-nodegroups --cluster-name ${self.triggers.cluster_name} --region ${self.triggers.region} | jq -r '.nodegroups[]' | while read -r nodegroup; do
        echo "Deleting nodegroup $nodegroup from cluster ${self.triggers.cluster_name}"
        aws eks delete-nodegroup --cluster-name ${self.triggers.cluster_name} --nodegroup-name $nodegroup --region ${self.triggers.region}
        
        # Wait for nodegroup to be deleted
        until ! aws eks describe-nodegroup --cluster-name ${self.triggers.cluster_name} --nodegroup-name $nodegroup --region ${self.triggers.region} 2>/dev/null; do
          echo "Waiting for nodegroup $nodegroup to be deleted..."
          sleep 30
        done
      done
      
      # Delete BazarStore resources first
      kubectl delete ingress --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete service --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete deployment --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete pvc --all -n bazarstore-prod --ignore-not-found=true
      kubectl delete pv postgres-pv-prod --ignore-not-found=true
      kubectl delete namespace bazarstore-prod --ignore-not-found=true
      
      # Delete test namespace resources
      kubectl delete ingress --all -n nginx-test --ignore-not-found=true
      kubectl delete service --all -n nginx-test --ignore-not-found=true
      kubectl delete namespace nginx-test --ignore-not-found=true
      
      # Wait for load balancers to be deleted
      echo "Waiting for ALB resources to be cleaned up by the controller..."
      sleep 30
      
      # Delete any orphaned ALB resources if still present
      for lb in $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`) == `true`].LoadBalancerArn' --output text); do
        echo "Deleting orphaned load balancer $lb"
        aws elbv2 delete-load-balancer --load-balancer-arn $lb || true
      done
      
      # Delete orphaned network interfaces that may be blocking VPC deletion
      echo "Finding and removing orphaned network interfaces..."
      for eni in $(aws ec2 describe-network-interfaces --filters "Name=description,Values=*ELB app/k8s-*" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text); do
        echo "Detaching and deleting network interface $eni"
        attachment=$(aws ec2 describe-network-interfaces --network-interface-ids $eni --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text)
        if [ "$attachment" != "None" ] && [ -n "$attachment" ]; then
          aws ec2 detach-network-interface --attachment-id $attachment --force || true
          sleep 10
        fi
        aws ec2 delete-network-interface --network-interface-id $eni || true
      done
    EOT
  }

  depends_on = [module.aws-eks-addons]
}