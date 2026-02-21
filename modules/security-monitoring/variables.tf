variable "security_alert_email" {
  description = "Email address for HIGH severity security alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
