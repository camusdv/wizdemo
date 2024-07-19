provider "aws" {
  region = "eu-west-3"  # Set your desired AWS region
}

# Variables
variable "cluster_name" {
  default = "fe-eks-cluster"
}

variable "eks_version" {
  default = "1.30"  # EKS version
}

variable "vpc_id" {
  default = "vpc-0de19b99f68ad9ce5"  # Replace with your VPC ID
}

variable "dbtier_subnet_id" {
  default = "subnet-0bf81bee22a4203e1"  # Replace with your dbtier subnet ID
}

variable "gateway_id" {
  default = "igw-0a598e0e3464ee679" # Replace with your IGW ID
}

variable "allowed_ssh_cidr" {
  description = "CIDR block for SSH access"
  default     = "203.0.113.0/24" # Replace with your allowed SSH CIDR
}

# Define your key pair
resource "aws_key_pair" "fetier_key" {
  key_name   = "fetier-key"
  public_key = file("<your .pub>")  # Path to your public key file
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-3a"
  map_public_ip_on_launch = true

  tags = {
    Name = "fetier-public-subnet-a"
    Environment = "dvdemosec"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-3b"
  map_public_ip_on_launch = true

  tags = {
    Name = "fetier-public-subnet-b"
    Environment = "dvdemosec"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id     = var.vpc_id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-west-3a"

  tags = {
    Name = "fetier-private-subnet-a"
    Environment = "dvdemosec"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = var.vpc_id
  cidr_block = "10.0.5.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "fetier-private-subnet-b"
    Environment = "dvdemosec"
  }
}

resource "aws_route_table" "fe_public_rt" {
  vpc_id = var.vpc_id

  tags = {
    Name = "fetier-public-router"
    Environment = "dvdemosec"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.fe_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.gateway_id
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.fe_public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.fe_public_rt.id
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "fe_nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "fetier-nat-gateway"
    Environment = "dvdemosec"
  }
}

resource "aws_route_table" "fe_private_rt" {
  vpc_id = var.vpc_id

  tags = {
    Name = "fetier-private-router"
    Environment = "dvdemosec"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.fe_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.fe_nat_gw.id
}

resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.fe_private_rt.id
}

resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.fe_private_rt.id
}

# IAM Roles and Policies

# Role for EKS Cluster
resource "aws_iam_role" "fe_eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach policies to EKS Cluster Role

resource "aws_iam_role_policy_attachment" "fe_eks_cluster_policy_attachment" {
  role      = aws_iam_role.fe_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Role for EKS Node Group
resource "aws_iam_role" "fe_eks_node_role" {
  name = "fe-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach policies to EKS Node Group Role

resource "aws_iam_role_policy_attachment" "fe_eks_node_policy_attachment" {
  role      = aws_iam_role.fe_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "fe_eks_cni_policy_attachment" {
  role       = aws_iam_role.fe_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "fe_eks_registry_policy_attachment" {
  role       = aws_iam_role.fe_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Security Group for EKS Cluster
resource "aws_security_group" "fe_eks_cluster_sg" {
  name        = "fe-eks-cluster-sg"
  description = "Security group for EKS cluster"

  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "fe-eks-ctrl-sg"
    Environment = "dvdemosec"
  }
}

resource "aws_security_group" "fe_eks_nodes_sg" {
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "fe-eks-nodes-sg"
    Environment = "dvdemosec"
  }
}

# Security Group
resource "aws_security_group" "fetiersg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]  # Restrict SSH access to allowed CIDR block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fetier-sg"
    Environment = "dvdemosec"
  }
}

# EC2 Instance
resource "aws_instance" "dbtier_test_instance" {
  ami                    = "ami-0062b622072515714"  # Ubuntu 22.04 eu-west-3
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_a.id
  security_groups        = [aws_security_group.fetiersg.id]
  associate_public_ip_address = false  # No public IP for private subnet

  key_name               = aws_key_pair.fetier_key.key_name  # Assigning the key pair to the instance

  user_data = <<-EOF
    #!/bin/bash
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update
    apt-get install gnupg curl
    apt-get install -y mongodb-org
  EOF

  tags = {
    Name = "MongoDBTester"
    Environment = "dvdemosec"
  }

  depends_on = [
    aws_security_group.fetiersg
  ]
}

resource "aws_eks_cluster" "fe-my-cluster" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = aws_iam_role.fe_eks_cluster_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
    security_group_ids = [aws_security_group.fe_eks_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.fe_eks_cluster_policy_attachment]
}

resource "aws_eks_node_group" "example_node_group" {
  cluster_name    = aws_eks_cluster.fe-my-cluster.name
  node_group_name = "example-node-group"
  node_role_arn   = aws_iam_role.fe_eks_node_role.arn
  subnet_ids      = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key = aws_key_pair.fetier_key.key_name
    source_security_group_ids = [aws_security_group.fe_eks_nodes_sg.id]  # Add security group for SSH access
  }

  depends_on = [aws_eks_cluster.fe-my-cluster]
}
