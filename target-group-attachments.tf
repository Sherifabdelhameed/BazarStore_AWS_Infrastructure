# Define a local variable for node count based on the desired_size in the node group
locals {
  eks_node_count = 2  # This matches the desired_size in aws-eks/node-groups.tf
}

# Get EKS node instance IDs - keep this for reference but don't use for count
data "aws_instances" "eks_nodes" {
  filter {
    name   = "tag:kubernetes.io/cluster/${module.aws-eks.cluster_name}"
    values = ["owned"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.aws-eks]
}

# Register EKS nodes with the target group using the static count
resource "aws_lb_target_group_attachment" "eks_node_attachment" {
  count            = local.eks_node_count
  target_group_arn = module.aws-alb.target_group_arn
  target_id        = data.aws_instances.eks_nodes.ids[count.index]
  port             = 30000

  depends_on = [data.aws_instances.eks_nodes]
  
  # Add lifecycle block to handle attachment failures gracefully
  lifecycle {
    ignore_changes = [target_id]
  }
}