# modules/tenant-account/main.tf
# Provisions a complete, security-hardened AWS baseline for a single tenant.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# VPC — dedicated per-tenant network boundary
# ---------------------------------------------------------------------------

resource "aws_vpc" "tenant" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-vpc"
    Tenant = var.tenant_id
  })
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.tenant.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-private-${var.availability_zones[count.index]}"
    Type   = "private"
    Tenant = var.tenant_id
  })
}

resource "aws_flow_log" "tenant" {
  vpc_id          = aws_vpc.tenant.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.tenant.arn

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-flow-logs"
    Tenant = var.tenant_id
  })
}

# ---------------------------------------------------------------------------
# Security Group — default deny, HTTPS egress to VPC endpoints only
# ---------------------------------------------------------------------------

resource "aws_security_group" "tenant_default" {
  name        = "${var.tenant_name}-default-sg"
  description = "${var.tenant_name}: default deny ingress, HTTPS egress to VPC endpoints only"
  vpc_id      = aws_vpc.tenant.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS to VPC endpoints within tenant VPC"
  }

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-default-sg"
    Tenant = var.tenant_id
  })
}

# ---------------------------------------------------------------------------
# KMS — per-tenant CMK, only the tenant workload role can use it for data ops
# ---------------------------------------------------------------------------

resource "aws_kms_key" "tenant" {
  description             = "Tenant encryption key: ${var.tenant_name}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowTenantWorkloadUse"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.tenant_workload.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-cmk"
    Tenant = var.tenant_id
  })
}

resource "aws_kms_alias" "tenant" {
  name          = "alias/${var.tenant_name}-key"
  target_key_id = aws_kms_key.tenant.key_id
}

# ---------------------------------------------------------------------------
# S3 — encrypted with tenant CMK, versioned, fully private
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tenant" {
  bucket = "${var.tenant_name}-data-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-data-bucket"
    Tenant = var.tenant_id
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tenant" {
  bucket = aws_s3_bucket.tenant.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tenant.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tenant" {
  bucket = aws_s3_bucket.tenant.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tenant" {
  bucket = aws_s3_bucket.tenant.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tenant" {
  bucket = aws_s3_bucket.tenant.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ---------------------------------------------------------------------------
# IAM — tenant workload role, scoped to tenant-owned resources only
# ---------------------------------------------------------------------------

resource "aws_iam_role" "tenant_workload" {
  name        = "${var.tenant_name}-workload-role"
  description = "Workload role for tenant ${var.tenant_name}. Scoped to tenant-owned resources only."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-workload-role"
    Tenant = var.tenant_id
  })
}

resource "aws_iam_role_policy" "tenant_workload_s3" {
  name = "${var.tenant_name}-data-access-policy"
  role = aws_iam_role.tenant_workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTenantS3Operations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.tenant.arn,
          "${aws_s3_bucket.tenant.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "AllowTenantKMSOperations"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.tenant.arn]
      }
    ]
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.tenant_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.tenant_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# GuardDuty member — enrolls this account into the security account master
# ---------------------------------------------------------------------------

resource "aws_guardduty_member" "tenant" {
  count = var.enable_guardduty && var.security_guardduty_detector_id != "" ? 1 : 0

  account_id         = data.aws_caller_identity.current.account_id
  detector_id        = var.security_guardduty_detector_id
  email              = var.tenant_security_email
  invite             = true
  invitation_message = "GuardDuty member enrollment for tenant: ${var.tenant_name}"
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group — encrypted with tenant CMK
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "tenant" {
  name              = "/tenant/${var.tenant_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.tenant.arn

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-log-group"
    Tenant = var.tenant_id
  })
}
