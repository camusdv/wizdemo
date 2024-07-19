#when deploying from older Operating Systems, e.g. Ubuntu 18.04
#terraform {
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = "~> 4.0"
#    }
#  }
#}

provider "aws" {
  region = "eu-west-3"
}

# Create VPC
resource "aws_vpc" "dbtier" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dbtier-vpc"
    Environment = "dvdemosec"
  }
}

resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.dbtier.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-3a"

  tags = {
    Name = "dbtier-subnet-a"
    Environment = "dvdemosec"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dbtier.id

  tags = {
    Name = "dbtier-igw"
    Environment = "dvdemosec"
  }
}

# Route Table
resource "aws_route_table" "router" {
  vpc_id = aws_vpc.dbtier.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "dbtier-router"
    Environment = "dvdemosec"
  }
}

# Associate Route Table
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.router.id
}

# Define your key pair
resource "aws_key_pair" "dbtier_key" {
  key_name   = "dbtier-key"
  public_key = file("<path to .pub>")  # Path to your public key file
}

# Security Group
resource "aws_security_group" "dbtiersg" {
  vpc_id = aws_vpc.dbtier.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dbtier-sg"
    Environment = "dvdemosec"
  }
}

# Add delay to ensure the security group is created and available
resource "null_resource" "wait_for_security_group" {
  provisioner "local-exec" {
    command = "sleep 1"
  }

  depends_on = [aws_security_group.dbtiersg]
}

# IAM Role
resource "aws_iam_role" "dbtier_ec2_role" {
  name = "dbtier_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "dbtier-ec2-role"
    Environment = "dvdemosec"
  }
}

# IAM Policy
resource "aws_iam_policy" "dbtier_ec2_policy" {
  name        = "dbtier_ec2_policy"
  description = "EC2 and S3 policy for instance"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:*"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::mongo-bkup-9b4e3640f0365c9b",
          "arn:aws:s3:::mongo-bkup-9b4e3640f0365c9b/*"
        ]
      }
    ]
  })

  tags = {
    Name = "dbtier-ec2-policy"
    Environment = "dvdemosec"
  }
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "dbtier_ec2_role_attachment" {
  role       = aws_iam_role.dbtier_ec2_role.name
  policy_arn = aws_iam_policy.dbtier_ec2_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "dbtier_instance_profile" {
  name = "dbtier_instance_profile"
  role = aws_iam_role.dbtier_ec2_role.name

  tags = {
    Name = "dbtier-instance-profile"
    Environment = "dvdemosec"
  }
}

# EC2 Instance
resource "aws_instance" "dbtier_instance" {
  ami                    = "ami-0062b622072515714"  # Ubuntu 22.04 eu-west-3
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet_public.id
  security_groups        = [aws_security_group.dbtiersg.id]
  iam_instance_profile   = aws_iam_instance_profile.dbtier_instance_profile.name
  associate_public_ip_address = true

  key_name               = aws_key_pair.dbtier_key.key_name  # Assigning the key pair to the instance

  user_data = <<-EOF
    #!/bin/bash
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update
    apt-get install gnupg curl net-tools unzip
    apt-get install -y mongodb-org
    #apt-get install -y awscli
    # Download AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    # Un-compress the archive
    unzip awscliv2.zip
    # Run the installer
    sudo ./aws/install

    # Enable MongoDB authentication
    sed -i 's/#security/security/' /etc/mongodb.conf
    echo "security:\n  authorization: 'enabled'" >> /etc/mongodb.conf
    
    # Start MongoDB
    systemctl start mongod.service
    systemctl enable mongod.service

    # Create MongoDB admin user
    mongosh <<-EOF2
      use admin
      db.createUser({
      user: 'admin',
      pwd: 'password',
      roles: [{ role: 'root', db: 'admin' }]
      })
    EOF2

    # Create backup script
    echo "#!/bin/bash" > /usr/local/bin/backup_mongodb.sh
    echo "mongodump --archive=/tmp/backup-$(date +\\%F).gz --gzip --username admin --password password" >> /usr/local/bin/backup_mongodb.sh
    echo "aws s3 cp /tmp/backup-$(date +\\%F).gz s3://mongo-bkup-9b4e3640f0365c9b/" >> /usr/local/bin/backup_mongodb.sh
    chmod +x /usr/local/bin/backup_mongodb.sh

    # Add backup script to cron
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup_mongodb.sh") | crontab -

  EOF

  tags = {
    Name = "MongoDBServer"
    Environment = "dvdemosec"
  }

  depends_on = [
    aws_security_group.dbtiersg,
    aws_iam_instance_profile.dbtier_instance_profile
  ]
}

# S3 Bucket for Backups
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "mongo-bkup-9b4e3640f0365c9b"

  tags = {
    Name = "mongo-bkup-9b4e3640f0365c9b"
    Environment = "dvdemosec"
  }
}

