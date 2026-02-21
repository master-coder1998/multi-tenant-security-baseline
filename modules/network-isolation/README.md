# Module: network-isolation

Provisions network-level isolation for a single tenant. All workloads run in private
subnets with no direct internet ingress. Internet-bound egress goes through a NAT Gateway;
AWS service calls go through VPC endpoints, keeping traffic on the AWS backbone.

## Design Principles

- **No public subnets for workloads** — all compute in private subnets
- **Default-deny security group** — no ingress allowed by default; egress scoped to VPC endpoints
- **No tenant-to-tenant routing** — VPCs are standalone; no peering
- **VPC endpoints** — S3 (Gateway), SSM and SSMMessages (Interface) included by default
- **NACLs** — subnet-level guardrail in addition to security groups

## Usage

```hcl
module "network" {
  source = "../../modules/network-isolation"

  tenant_name        = "acme-corp"
  vpc_cidr           = "10.100.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway = true

  tags = {
    Tenant    = "AcmeCorp"
    ManagedBy = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `tenant_name` | Tenant name (used in resource naming) | `string` | — | yes |
| `vpc_cidr` | VPC CIDR block (must not overlap other tenants) | `string` | `10.0.0.0/16` | no |
| `availability_zones` | AZs for private subnet deployment | `list(string)` | `["us-east-1a","us-east-1b"]` | no |
| `enable_nat_gateway` | Deploy NAT Gateway for internet egress | `bool` | `true` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `private_subnet_ids` | Private subnet IDs |
| `default_security_group_id` | Default-deny security group ID |
| `s3_vpc_endpoint_id` | S3 Gateway VPC endpoint ID |
