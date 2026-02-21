# examples/full-platform/main.tf
# Full multi-tenant deployment: security account + multiple tenants.
# Run the security-monitoring module first to get the GuardDuty detector ID.

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region

  # Security account provider
  alias = "security"

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/TerraformDeployRole"
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Step 1: Deploy centralized security monitoring (in the security account)
# ---------------------------------------------------------------------------

module "security_monitoring" {
  source = "../../modules/security-monitoring"

  providers = {
    aws = aws.security
  }

  security_alert_email = var.security_alert_email

  tags = {
    ManagedBy   = "terraform"
    Environment = "security"
  }
}

# ---------------------------------------------------------------------------
# Step 2: Deploy each tenant account with the security baseline
# ---------------------------------------------------------------------------

module "tenant_acme_corp" {
  source = "../../modules/tenant-account"

  tenant_name           = "acme-corp"
  tenant_id             = "tenant-001"
  vpc_cidr              = "10.100.0.0/16"
  security_account_id   = var.security_account_id
  tenant_security_email = "security@acmecorp.com"

  enable_guardduty               = true
  security_guardduty_detector_id = module.security_monitoring.guardduty_detector_id
  log_retention_days             = 90

  tags = {
    Tenant      = "AcmeCorp"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "tenant_globex" {
  source = "../../modules/tenant-account"

  tenant_name           = "globex"
  tenant_id             = "tenant-002"
  vpc_cidr              = "10.101.0.0/16"   # Non-overlapping CIDR
  security_account_id   = var.security_account_id
  tenant_security_email = "security@globex.com"

  enable_guardduty               = true
  security_guardduty_detector_id = module.security_monitoring.guardduty_detector_id
  log_retention_days             = 90

  tags = {
    Tenant      = "Globex"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "guardduty_detector_id" {
  description = "GuardDuty master detector ID (needed for adding more tenants)"
  value       = module.security_monitoring.guardduty_detector_id
}

output "tenant_acme_vpc_id" {
  value = module.tenant_acme_corp.vpc_id
}

output "tenant_globex_vpc_id" {
  value = module.tenant_globex.vpc_id
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "security_account_id" {
  type = string
}

variable "security_alert_email" {
  type = string
}
