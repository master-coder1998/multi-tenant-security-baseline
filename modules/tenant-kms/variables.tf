variable "tenant_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "tenant_workload_role_arn" {
  description = "ARN of the IAM role that is permitted to use this key for data encryption/decryption"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Number of days to wait before deleting the key (supports GDPR erasure). Min 7, max 30."
  type        = number
  default     = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
