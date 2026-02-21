# modules/tenant-account/variables.tf

variable "tenant_name" {
  description = "Unique name for the tenant (used in resource naming, e.g. 'acme-corp')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.tenant_name))
    error_message = "tenant_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "tenant_id" {
  description = "Unique identifier for the tenant (e.g. 'acme-001')"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the tenant VPC. Must not overlap with other tenants."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for private subnet deployment (minimum 2 for HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "security_account_id" {
  description = "AWS account ID of the centralized security account"
  type        = string
}

variable "enable_guardduty" {
  description = "Enrol this tenant account as a GuardDuty member"
  type        = bool
  default     = true
}

variable "security_guardduty_detector_id" {
  description = "GuardDuty detector ID in the security (master) account. Required if enable_guardduty is true."
  type        = string
  default     = ""
}

variable "tenant_security_email" {
  description = "Contact email for security notifications for this tenant"
  type        = string
}

variable "kms_deletion_window" {
  description = "Number of days before KMS key is deleted after removal (supports GDPR right-to-erasure). Min 7, max 30."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "kms_deletion_window must be between 7 and 30 days."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
