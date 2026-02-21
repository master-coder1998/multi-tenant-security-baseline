# modules/security-monitoring/main.tf
# Centralized security monitoring infrastructure for all tenant accounts.
# Deploy this in a dedicated security account separate from all tenants.

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
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# S3 — centralized log archive (CloudTrail, VPC Flow Logs)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "security_logs" {
  bucket = "security-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name    = "security-logs-archive"
    Purpose = "centralized-log-archive"
  })
}

resource "aws_s3_bucket_public_access_block" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket policy allowing CloudTrail to write
resource "aws_s3_bucket_policy" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.security_logs.arn
      },
      {
        Sid    = "AllowCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.security_logs.arn}/cloudtrail/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# GuardDuty — master detector; tenant accounts enrol as members
# ---------------------------------------------------------------------------

resource "aws_guardduty_detector" "master" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = "security-guardduty-master"
  })
}

# ---------------------------------------------------------------------------
# SNS — security alert topics
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "security_alerts_high" {
  name = "security-alerts-high"

  tags = merge(var.tags, {
    Name     = "security-alerts-high"
    Severity = "HIGH"
  })
}

resource "aws_sns_topic" "security_alerts_medium" {
  name = "security-alerts-medium"

  tags = merge(var.tags, {
    Name     = "security-alerts-medium"
    Severity = "MEDIUM"
  })
}

resource "aws_sns_topic_subscription" "security_alerts_high_email" {
  count     = var.security_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts_high.arn
  protocol  = "email"
  endpoint  = var.security_alert_email
}

# ---------------------------------------------------------------------------
# EventBridge — route GuardDuty HIGH findings to SNS
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "guardduty_high_findings" {
  name        = "guardduty-high-severity-findings"
  description = "Route GuardDuty HIGH severity findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts_high.arn
}

resource "aws_sns_topic_policy" "security_alerts_high" {
  arn = aws_sns_topic.security_alerts_high.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security_alerts_high.arn
      }
    ]
  })
}
