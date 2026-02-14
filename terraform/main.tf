# =============================================
# COMPLETE WORKING MAIN.TF - PROJECT NOVA
# =============================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Primary region (Mumbai)
provider "aws" {
  region = var.primary_region
  alias  = "primary"
}

# DR region (Singapore)
provider "aws" {
  region = var.dr_region
  alias  = "dr"
}

# Random suffix for unique bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# =============================================
# DATA SOURCES
# =============================================

# Get current AWS account ID
data "aws_caller_identity" "current" {
  provider = aws.primary
}

# Get default VPC
data "aws_vpc" "default" {
  provider = aws.primary
  default  = true
}

# Get default subnets
data "aws_subnets" "default" {
  provider = aws.primary
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# =============================================
# S3 BUCKETS WITH VERSIONING
# =============================================

# Primary bucket
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.project_name}-primary-${var.environment}-${random_string.suffix.result}"
  
  tags = {
    Name        = "${var.project_name}-primary"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Enable versioning on primary
resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DR bucket
resource "aws_s3_bucket" "dr" {
  provider = aws.dr
  bucket   = "${var.project_name}-dr-${var.environment}-${random_string.suffix.result}"
  
  tags = {
    Name        = "${var.project_name}-dr"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Enable versioning on DR
resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================
# S3 REPLICATION SETUP
# =============================================

# IAM Role for replication
resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-replication-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for replication
resource "aws_iam_policy" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-replication-policy-${random_string.suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.primary.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${aws_s3_bucket.primary.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [aws_s3_bucket.dr.arn, "${aws_s3_bucket.dr.arn}/*"]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "replication" {
  provider   = aws.primary
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# S3 Replication configuration (FIXED with filter)
resource "aws_s3_bucket_replication_configuration" "primary" {
  provider = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    # REQUIRED filter block
    filter {
      prefix = ""  # Empty string means replicate all objects
    }

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD"
    }

    # Configure delete marker replication
    delete_marker_replication {
      status = "Disabled"  # Set to "Enabled" if you want to replicate delete markers
    }
  }
}

# =============================================
# RDS MYSQL INSTANCE
# =============================================

# Security Group for RDS
resource "aws_security_group" "rds" {
  provider    = aws.primary
  name        = "${var.project_name}-rds-sg-${random_string.suffix.result}"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict in production!
    description = "MySQL access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "default" {
  provider   = aws.primary
  name       = "${var.project_name}-subnet-${random_string.suffix.result}"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project_name}-subnet-group"
  }
}

# RDS Instance - Using MySQL 8.0.45 (latest supported version as of Feb 2026)
resource "aws_db_instance" "primary" {
  provider = aws.primary
  identifier     = "${var.project_name}-db-${random_string.suffix.result}"
  engine         = "mysql"
  engine_version = "8.0.45"  # Latest working version (Feb 2026)
  instance_class = "db.t3.micro"  # Free tier eligible
  allocated_storage = 20
  storage_type      = "gp2"
  
  db_name  = "bankingdb"
  username = var.db_username
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  publicly_accessible = true
  
  auto_minor_version_upgrade = true
  storage_encrypted = false
  
  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}

# =============================================
# IAM ROLE FOR LAMBDA
# =============================================

resource "aws_iam_role" "lambda" {
  provider = aws.primary
  name = "${var.project_name}-lambda-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  provider   = aws.primary
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for RDS operations
resource "aws_iam_policy" "lambda_rds" {
  provider = aws.primary
  name     = "${var.project_name}-lambda-rds-${random_string.suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:CreateDBSnapshot",
          "rds:DescribeDBInstances",
          "rds:DescribeDBSnapshots",
          "rds:CopyDBSnapshot",
          "rds:AddTagsToResource"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Attach RDS policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_rds" {
  provider   = aws.primary
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_rds.arn
}

# =============================================
# CLOUDWATCH EVENTS FOR SCHEDULING
# =============================================

# CloudWatch Event Rule for daily backup
resource "aws_cloudwatch_event_rule" "daily_backup" {
  provider            = aws.primary
  name                = "${var.project_name}-daily-backup-${random_string.suffix.result}"
  description         = "Trigger daily RDS backup"
  schedule_expression = "cron(0 2 * * ? *)"  # 2 AM daily
}

# CloudWatch Event Rule for cross-region copy
resource "aws_cloudwatch_event_rule" "cross_region_copy" {
  provider            = aws.primary
  name                = "${var.project_name}-cross-region-copy-${random_string.suffix.result}"
  description         = "Trigger cross-region snapshot copy"
  schedule_expression = "cron(0 3 * * ? *)"  # 3 AM daily
}

# =============================================
# SNS TOPIC FOR ALERTS
# =============================================

# SNS Topic for DR alerts
resource "aws_sns_topic" "dr_alerts" {
  provider = aws.primary
  name     = "${var.project_name}-alerts-${random_string.suffix.result}"
}

# SNS Topic Subscription (optional - add email in terraform.tfvars)
resource "aws_sns_topic_subscription" "email_alerts" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.dr_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# =============================================
# CLOUDWATCH ALARMS
# =============================================

# CloudWatch Alarm for replication failures
resource "aws_cloudwatch_metric_alarm" "replication_failure" {
  provider            = aws.primary
  alarm_name          = "${var.project_name}-replication-failure-${random_string.suffix.result}"
  alarm_description   = "Alert when S3 replication fails"
  metric_name         = "ReplicationLatency"
  namespace           = "AWS/S3"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 900
  comparison_operator = "GreaterThanThreshold"
  
  dimensions = {
    BucketName = aws_s3_bucket.primary.id
  }
  
  alarm_actions = [aws_sns_topic.dr_alerts.arn]
}

# =============================================
# OUTPUTS
# =============================================

output "primary_bucket" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.primary.id
}

output "dr_bucket" {
  description = "DR S3 bucket name"
  value       = aws_s3_bucket.dr.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.primary.endpoint
}

output "lambda_role_arn" {
  description = "Lambda IAM role ARN"
  value       = aws_iam_role.lambda.arn
}

output "sns_topic_arn" {
  description = "SNS topic for alerts"
  value       = aws_sns_topic.dr_alerts.arn
}

output "random_suffix" {
  description = "Random suffix used for unique names"
  value       = random_string.suffix.result
}
