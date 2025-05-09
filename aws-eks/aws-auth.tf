resource "kubernetes_config_map_v1_data" "aws_auth_users" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapUsers = yamlencode([
      {
        userarn  = "arn:aws:iam::537124967157:user/SherifAbdelhameed"
        username = "sherifabdelhameed"
        groups   = ["system:masters"]
      }
    ])
  }

  force = true

  depends_on = [
    aws_eks_node_group.example
  ]
}