data "aws_iam_role" "terraform_ci" {
  name = "github-actions-terraform"
}

data "aws_iam_role" "terraform_plan" {
  name = "github-actions-terraform-plan"
}

resource "aws_eks_access_entry" "terraform_ci" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.terraform_ci.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_ci" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.terraform_ci.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_ci]
}

resource "aws_eks_access_entry" "terraform_plan" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.terraform_plan.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "terraform_plan" {
  cluster_name  = module.eks.cluster_name
  principal_arn = data.aws_iam_role.terraform_plan.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.terraform_plan]
}
