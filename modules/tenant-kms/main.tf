# modules/tenant-kms/main.tf
# Manages per-tenant KMS Customer Managed Keys with strict, tenant-scoped key policies.

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

resource "aws_kms_key" "tenant" {
  description             = "Customer Managed Key for tenant: ${var.tenant_name}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootAccountManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowTenantDataOperations"
        Effect = "Allow"
        Principal = {
          AWS = var.tenant_workload_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllOtherPrincipals"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
              var.tenant_workload_role_arn
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name   = "${var.tenant_name}-cmk"
    Tenant = var.tenant_id
  })
}

resource "aws_kms_alias" "tenant" {
  name          = "alias/${var.tenant_name}-cmk"
  target_key_id = aws_kms_key.tenant.key_id
}
