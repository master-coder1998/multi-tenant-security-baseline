# Module: security-monitoring

Deploys the centralized security monitoring stack into a dedicated security account.
All tenant accounts report GuardDuty findings and Config compliance back to this account.

## Resources Created

- S3 bucket for centralized log archive (CloudTrail, VPC Flow Logs)
- GuardDuty master detector with S3, Kubernetes, and malware protection enabled
- SNS topics for HIGH and MEDIUM severity security alerts
- EventBridge rule routing GuardDuty HIGH findings (severity ≥ 7) to SNS
- SNS email subscription for security alert notifications

## Usage

Deploy this module **first** in your security account, then pass the `guardduty_detector_id` output into each `tenant-account` module.

```hcl
module "security_monitoring" {
  source = "../../modules/security-monitoring"

  security_alert_email = "security-team@example.com"

  tags = {
    ManagedBy   = "terraform"
    Environment = "security"
  }
}

# Pass the detector ID to tenant modules
module "tenant_a" {
  source = "../../modules/tenant-account"

  security_guardduty_detector_id = module.security_monitoring.guardduty_detector_id
  # ...
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `security_alert_email` | Email for HIGH severity alert subscriptions | `string` | `""` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `guardduty_detector_id` | GuardDuty master detector ID (pass to tenant-account modules) |
| `security_logs_bucket` | Centralized log archive S3 bucket name |
| `high_severity_sns_arn` | HIGH severity SNS topic ARN |
| `medium_severity_sns_arn` | MEDIUM severity SNS topic ARN |
