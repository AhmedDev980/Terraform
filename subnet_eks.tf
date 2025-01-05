/* create 4 subnets from cidr range 10.16.0.0/22.
Find changed CIDR and subnet ids, use these subnet ids to create sub nets and EKS cluster in one of those subnets, having 2 min and 3 max nodes using terraform in aws. */

/* A /22 network has 1024 IP addresses (2^(32-22) = 1024 addresses).

We want to split this into 4 subnets. To do this, we need to borrow 2 more bits from the host part (because 2^2 = 4, which gives us the 4 subnets we need).

The new subnet mask will be /24 (22 + 2 = 24).
Each /24 subnet will have 256 IP addresses (2^(32-24) = 256 addresses). */

# Terraform Code for Subnet Creation and EKS Setup
provider "aws" {
  region = "us-west-2"  # Update to your region
}

# Define VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.16.0.0/22"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.16.0.0/24"
  availability_zone       = "us-west-2a"  # Update based on your region
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.16.1.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.16.2.0/24"
  availability_zone       = "us-west-2c"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_4" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.16.3.0/24"
  availability_zone       = "us-west-2d"
  map_public_ip_on_launch = true
}

# Create EKS Cluster
resource "aws_eks_cluster" "my_eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.subnet_1.id, # You can choose any subnet here
      aws_subnet.subnet_2.id,
      aws_subnet.subnet_3.id,
      aws_subnet.subnet_4.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment]
}

# IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Attach policies to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create Node Group (with minimum 2 and maximum 3 nodes)
resource "aws_eks_node_group" "my_eks_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [
    aws_subnet.subnet_1.id, # Use the subnet you want for the EKS nodes
    aws_subnet.subnet_2.id
  ]
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  depends_on = [aws_eks_cluster.my_eks_cluster]
}

# IAM role for the EKS node group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Attach policies to the EKS node role
resource "aws_iam_role_policy_attachment" "eks_node_role_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Output EKS Cluster Endpoint and Kubeconfig
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.my_eks_cluster.endpoint
}

output "eks_cluster_kubeconfig" {
  value = aws_eks_cluster.my_eks_cluster.kubeconfig[0].value
}
