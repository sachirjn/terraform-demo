# Virtual Private Cloud
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = var.vpc_name
  cidr                 = "10.0.0.0/16"
  azs                  = ["ap-southeast-1a","ap-southeast-1b" ]
  private_subnets      = ["10.0.1.0/24","10.0.2.0/24"] 
  public_subnets       = ["10.0.3.0/24","10.0.4.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# Security Groups
resource "aws_security_group" "security_group" {
  name_prefix = "sg_sachi_development"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.17"
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  worker_groups = [
    {
      name                          = "worker-group-${var.environment}"
      instance_type                 = "t2.micro"
      additional_userdata           = "sachi development"
      asg_min_size                  = var.min_size
      asg_desired_capacity          = var.desired_size
      asg_max_size                  = var.max_size
      additional_security_group_ids = [aws_security_group.security_group.id]
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
