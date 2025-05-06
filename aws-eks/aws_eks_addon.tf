resource "aws_eks_addon" "aws_load_balancer_controller" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "aws-load-balancer-controller"
}