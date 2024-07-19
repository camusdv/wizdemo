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

# S3 bucket for AWS Config
resource "aws_s3_bucket" "dvsecdemo_config_bucket" {
  bucket = "dvsecdemo-bucket-9b4e3640f0365c9b"

  tags = {
    Environment = "dvdemosec"
  }
}

# SNS topic for AWS Config notifications
resource "aws_sns_topic" "dvsecdemo_config_topic" {
  name = "dvsecdemo-topic-9b4e3640f0365c9b"

  tags = {
    Environment = "dvdemosec"
  }
}

# IAM role for AWS Config
resource "aws_iam_role" "dvsecdemo_config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "dvdemosec"
  }
}

# IAM policy for AWS Config role
resource "aws_iam_policy" "dvsecdemo_config_policy" {
  name = "dvsecdemo-policy-9b4e3640f0365c9b"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = "${aws_s3_bucket.dvsecdemo_config_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.dvsecdemo_config_topic.arn
      },
      {
        Effect = "Allow"
        Action = [
          "config:Put*",
          "config:BatchPut*",
          "config:Deliver*",
          "config:Describe*",
          "config:Get*",
          "config:List*",
          "config:Start*",
          "config:Stop*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "dvdemosec"
  }
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "dvsecdemo_config_role_attachment" {
  role       = aws_iam_role.dvsecdemo_config_role.name
  policy_arn = aws_iam_policy.dvsecdemo_config_policy.arn
}

# AWS Config Configuration Recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "default"
  role_arn = aws_iam_role.dvsecdemo_config_role.arn

  recording_group {
    all_supported              = true
    include_global_resource_types = true
  }

  depends_on = [
    aws_iam_role.dvsecdemo_config_role,
    aws_iam_role_policy_attachment.dvsecdemo_config_role_attachment
  ]

}

# AWS Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.dvsecdemo_config_bucket.bucket
  sns_topic_arn  = aws_sns_topic.dvsecdemo_config_topic.arn

  depends_on = [
    aws_config_configuration_recorder.main
  ]

}

# AWS Config Configuration Recorder Status
resource "aws_config_configuration_recorder_status" "main" {
  name      = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [
    aws_config_delivery_channel.main
  ]

}

# AWS Config Rule for EC2 instance type check with tag filtering
resource "aws_config_config_rule" "ec2_instance_type_check" {
  name = "ec2-instance-type-check"

  source {
    owner             = "AWS"
    source_identifier = "DESIRED_INSTANCE_TYPE"
  }

  input_parameters = jsonencode({
    instanceType = "t2.micro"
  })

  scope {
    tag_key = "Environment"
    tag_value = "dvdemosec"
  }

  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Environment = "dvdemosec"
  }
}

# AWS Config Rule for EKS cluster logging
resource "aws_config_config_rule" "eks_cluster_logging" {
  name = "eks-cluster-logging-enabled"

  source {
    owner             = "AWS"
    source_identifier = "EKS_CLUSTER_LOGGING_ENABLED"
  }

  scope {
    tag_key = "Environment"
    tag_value = "dvdemosec"
  }

  depends_on = [aws_config_configuration_recorder_status.main]
  
  tags = {
    Environment = "dvdemosec"
  }
}

# AWS Config Rule for S3 bucket versioning
resource "aws_config_config_rule" "s3_bucket_versioning" {
  name = "s3-bucket-versioning-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }

  scope {
    tag_key = "Environment"
    tag_value = "dvdemosec"
  }
  
  depends_on = [aws_config_configuration_recorder_status.main]

  tags = {
    Environment = "dvdemosec"
  }
}
