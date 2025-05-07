# Get EKS node instance IDs
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

# Register EKS nodes with the target group
resource "aws_lb_target_group_attachment" "eks_node_attachment" {
  count            = length(data.aws_instances.eks_nodes.ids)
  target_group_arn = module.aws-alb.target_group_arn
  target_id        = data.aws_instances.eks_nodes.ids[count.index]
  port             = 30000
}