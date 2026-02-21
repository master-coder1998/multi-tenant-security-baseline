# examples/basic-tenant/main.tf
# Deploy a single tenant with the full security baseline.

terraform {
  required_version = ">= 1.0"

  # Uncomment and configure for remote state:
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "tenants/acme-corp/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

module "tenant_acme_corp" {
  source = "../../modules/tenant-account"

  tenant_name           = "acme-corp"
  tenant_id             = "acme-001"
  vpc_cidr              = "10.100.0.0/16"
  security_account_id   = var.security_account_id
  tenant_security_email = "security@acmecorp.com"

  availability_zones = [
    "${var.aws_region}a",
    "${var.aws_region}b",
    "${var.aws_region}c",
  ]

  enable_guardduty               = true
  security_guardduty_detector_id = var.guardduty_detector_id
  log_retention_days             = 90
  kms_deletion_window            = 30

  tags = {
    Tenant      = "AcmeCorp"
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "multi-tenant-baseline"
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "Tenant VPC ID"
  value       = module.tenant_acme_corp.vpc_id
}

output "kms_key_arn" {
  description = "Tenant CMK ARN"
  value       = module.tenant_acme_corp.kms_key_arn
}

output "s3_bucket_name" {
  description = "Tenant S3 data bucket"
  value       = module.tenant_acme_corp.s3_bucket_name
}

output "workload_role_arn" {
  description = "Tenant workload IAM role ARN"
  value       = module.tenant_acme_corp.workload_role_arn
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "security_account_id" {
  type = string
}

variable "guardduty_detector_id" {
  type    = string
  default = ""
}
