output "guardduty_detector_id" {
  description = "GuardDuty master detector ID — required for tenant-account module"
  value       = aws_guardduty_detector.master.id
}

output "security_logs_bucket" {
  description = "Name of the centralized security log archive bucket"
  value       = aws_s3_bucket.security_logs.id
}

output "high_severity_sns_arn" {
  description = "ARN of the HIGH severity security alerts SNS topic"
  value       = aws_sns_topic.security_alerts_high.arn
}

output "medium_severity_sns_arn" {
  description = "ARN of the MEDIUM severity security alerts SNS topic"
  value       = aws_sns_topic.security_alerts_medium.arn
}
