# Module: tenant-account

Provisions a complete, security-hardened AWS baseline for a single tenant.

## Resources Created

- VPC with private subnets across multiple AZs
- VPC Flow Logs (all traffic, CloudWatch destination)
- Default-deny security group
- Per-tenant KMS CMK with automatic rotation
- Encrypted, versioned S3 data bucket (KMS SSE)
- Least-privilege IAM workload role
- GuardDuty member enrollment
- CloudWatch Log Group (encrypted with tenant CMK)

## Usage

```hcl
module "tenant_acme" {
  source = "../../modules/tenant-account"

  tenant_name           = "acme-corp"
  tenant_id             = "acme-001"
  vpc_cidr              = "10.100.0.0/16"
  security_account_id   = "999999999999"
  tenant_security_email = "security@acmecorp.com"

  tags = {
    Tenant      = "AcmeCorp"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `tenant_name` | Unique tenant name (lowercase, hyphens) | `string` | — | yes |
| `tenant_id` | Unique tenant identifier | `string` | — | yes |
| `vpc_cidr` | VPC CIDR block (must not overlap other tenants) | `string` | `10.0.0.0/16` | no |
| `availability_zones` | List of AZs for subnets | `list(string)` | `["us-east-1a","us-east-1b"]` | no |
| `security_account_id` | Centralized security account ID | `string` | — | yes |
| `tenant_security_email` | Security contact email | `string` | — | yes |
| `enable_guardduty` | Enrol as GuardDuty member | `bool` | `true` | no |
| `security_guardduty_detector_id` | GuardDuty master detector ID | `string` | `""` | no |
| `kms_deletion_window` | KMS key deletion window (days) | `number` | `30` | no |
| `log_retention_days` | CloudWatch log retention (days) | `number` | `90` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | Tenant VPC ID |
| `private_subnet_ids` | Private subnet IDs |
| `kms_key_arn` | Tenant CMK ARN |
| `s3_bucket_name` | Tenant S3 bucket name |
| `workload_role_arn` | Workload IAM role ARN |
| `log_group_name` | CloudWatch log group name |
