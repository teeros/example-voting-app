# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets from the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Allow public access to the cluster API
  cluster_endpoint_public_access = true

  # Managed node group
  eks_managed_node_groups = {
    general = {
      instance_types = [var.node_instance_type]
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      labels = {
        role = "general"
      }
    }
  }

  tags = {
    Project     = "voting-app"
    Environment = "capstone"
    ManagedBy   = "terraform"
  }
}
