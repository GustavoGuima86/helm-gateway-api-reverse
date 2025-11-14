# Terraform for AWS VPC Lattice Controller IAM Setup

# This Terraform config creates the IAM policy, role, and Kubernetes service account for the AWS VPC Lattice controller.
# It does NOT create the EKS cluster (assumed to exist).

provider "aws" {
  region = var.region
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "guto-cluster"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

locals {
  account_id = element(split(":", data.aws_eks_cluster.this.arn), 4)
  oidc_host  = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = data.aws_eks_cluster.this.identity[0].oidc[0].issuer != null ? "arn:aws:iam::${local.account_id}:oidc-provider/${local.oidc_host}" : null
  node_security_group_id = try(data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id, null)
}

resource "aws_iam_policy" "vpc_lattice_controller" {
  name        = "VPCLatticeControllerIAMPolicy"
  description = "Policy for AWS VPC Lattice controller"
  policy      = file("${path.module}/vpc-lattice-controller-policy.json")
}

# Pod Identity Role (optional)
resource "aws_iam_role" "vpc_lattice_controller_podid" {
  name = "VPCLatticeControllerIAMRole-PodId"
  assume_role_policy = file("${path.module}/eks-pod-identity-trust-relationship.json")
}

resource "aws_iam_role_policy_attachment" "attach_policy_podid" {
  role       = aws_iam_role.vpc_lattice_controller_podid.name
  policy_arn = aws_iam_policy.vpc_lattice_controller.arn
}

# Security group ingress for VPC Lattice prefix lists (optional)
data "aws_ec2_managed_prefix_list" "lattice_ipv4" {
  name = "com.amazonaws.${var.region}.vpc-lattice"
}

data "aws_ec2_managed_prefix_list" "lattice_ipv6" {
  name = "com.amazonaws.${var.region}.ipv6.vpc-lattice"
}

resource "aws_security_group_rule" "lattice_ipv4_ingress" {
  count = local.node_security_group_id != null ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = local.node_security_group_id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.lattice_ipv4.id]
}

resource "aws_security_group_rule" "lattice_ipv6_ingress" {
  count = local.node_security_group_id != null ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = local.node_security_group_id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.lattice_ipv6.id]
}

output "podid_role_arn" {
  value = aws_iam_role.vpc_lattice_controller_podid.arn
}
output "VPCLatticeControllerIAMPolicy" {
    value = aws_iam_policy.vpc_lattice_controller.arn
  
}