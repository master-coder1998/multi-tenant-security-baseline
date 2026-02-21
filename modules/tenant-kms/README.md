# Module: tenant-kms

Manages a per-tenant KMS Customer Managed Key (CMK) with a strict key policy that enforces
cryptographic data isolation between tenants. Only the named tenant workload role can perform
data encryption and decryption operations.

## Key Policy Design

- **Account root** — can manage the key (rotate, schedule deletion, update policy) but cannot use it for data operations
- **Tenant workload role** — can use `kms:Decrypt`, `kms:GenerateDataKey`, `kms:DescribeKey`
- **All other principals** — explicitly denied `kms:Decrypt` and `kms:GenerateDataKey`
- **Automatic key rotation** — enabled (annual)
- **Deletion window** — 30 days (supports GDPR right-to-erasure: scheduling deletion makes all encrypted data unrecoverable)

## Usage

```hcl
module "tenant_kms" {
  source = "../../modules/tenant-kms"

  tenant_name              = "acme-corp"
  tenant_id                = "acme-001"
  tenant_workload_role_arn = module.tenant_account.workload_role_arn
  deletion_window_in_days  = 30

  tags = {
    Tenant    = "AcmeCorp"
    ManagedBy = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `tenant_name` | Tenant name (used in key alias and tags) | `string` | — | yes |
| `tenant_id` | Tenant identifier | `string` | — | yes |
| `tenant_workload_role_arn` | IAM role ARN permitted to use this key | `string` | — | yes |
| `deletion_window_in_days` | Days before key is permanently deleted (7–30) | `number` | `30` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `key_id` | KMS key ID |
| `key_arn` | KMS key ARN |
| `alias_name` | KMS key alias |
