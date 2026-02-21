# 🏢 Multi-Tenant Security Baseline

> Production-ready Terraform modules for securing multi-tenant SaaS platforms on AWS

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-7B42BC)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Multi--Account-FF9900)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Terraform Validate](https://github.com/master-coder1998/multi-tenant-security-baseline/actions/workflows/terraform-validate.yml/badge.svg)](https://github.com/master-coder1998/multi-tenant-security-baseline/actions)

A comprehensive security baseline for multi-tenant SaaS architectures — implementing account-level tenant isolation, centralized security monitoring, per-tenant encryption, and automated compliance checks. Designed for platforms that need to meet SOC 2, ISO 27001, and CIS benchmark requirements for enterprise customers.

---

## 🎯 Overview

Multi-tenant SaaS platforms face a distinct set of security challenges that generic cloud security guides rarely address:

- **Tenant isolation** — A breach in one tenant must not impact others
- **Compliance at scale** — SOC 2 and ISO 27001 requirements across every customer account  
- **Operational efficiency** — Security must be automated, not a manual checklist
- **Right to deletion** — GDPR requires the ability to cryptographically erase tenant data

This project provides reusable Terraform modules that encode best practices for all of the above.

### Key Features

| Feature | Implementation |
|---|---|
| Tenant Isolation | Separate AWS account per tenant |
| Encryption | Per-tenant KMS CMKs with automatic rotation |
| Centralized Monitoring | GuardDuty + Security Hub + CloudTrail aggregated in a dedicated security account |
| Network Security | Private VPCs, default-deny security groups, VPC endpoints |
| Compliance | AWS Config rules mapped to SOC 2, CIS, and ISO 27001 |
| Infrastructure as Code | 100% Terraform — no manual console steps |
| Scalability | Add a new tenant by invoking one Terraform module |

---

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    AWS Organization (Root)                     │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Security Account (Centralized)             │   │
│  │                                                         │   │
│  │  • GuardDuty Master          • CloudTrail Org Trail     │   │
│  │  • Security Hub Aggregator   • AWS Config Aggregator    │   │
│  │  • SNS Security Alerts       • EventBridge Automation   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Shared Services Account                    │   │
│  │                                                         │   │
│  │  • Transit Gateway           • Route 53 Private Zones   │   │
│  │  • Secrets Manager           • Backup Vault             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                │
│  ┌──────────────────────┐   ┌──────────────────────┐           │
│  │   Tenant A Account   │   │   Tenant B Account   │   ···     │
│  │                      │   │                      │           │
│  │  • Isolated VPC      │   │  • Isolated VPC      │           │
│  │  • Tenant KMS Key    │   │  • Tenant KMS Key    │           │
│  │  • S3 (encrypted)    │   │  • S3 (encrypted)    │           │
│  │  • GuardDuty Member  │   │  • GuardDuty Member  │           │
│  │  • Security Hub Mbr  │   │  • Security Hub Mbr  │           │
│  └──────────────────────┘   └──────────────────────┘           │
└────────────────────────────────────────────────────────────────┘
```

### Security Controls by Layer

| Layer | Control | Implementation |
|---|---|---|
| Identity | Tenant isolation | Separate AWS accounts |
| Identity | Least privilege | SCPs + permission boundaries |
| Identity | Cross-account access | IAM roles with external ID |
| Data | Encryption at rest | Per-tenant KMS CMK |
| Data | Encryption in transit | TLS 1.3, VPC endpoints |
| Network | Isolation | Dedicated VPC, no tenant-to-tenant peering |
| Network | Controlled egress | NAT Gateway, VPC endpoints |
| Monitoring | Centralized logging | Organization CloudTrail |
| Monitoring | Threat detection | GuardDuty (aggregated) |
| Monitoring | Security posture | Security Hub + Config |
| Compliance | Drift detection | AWS Config rules |
| Compliance | Automated remediation | EventBridge + Lambda |

---

## 📦 Modules

### [`tenant-account`](modules/tenant-account/)

Provisions a complete, security-hardened baseline for a single tenant.

**Creates:** VPC with private subnets, per-tenant KMS key, encrypted S3 bucket, least-privilege IAM workload role, GuardDuty member enrollment, CloudWatch log group.

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
  }
}
```

---

### [`security-monitoring`](modules/security-monitoring/)

Deploys the centralized security account infrastructure that aggregates findings from all tenant accounts.

**Creates:** GuardDuty master, Security Hub aggregator, SNS alert topics, EventBridge automation rules, S3 log archive bucket.

---

### [`tenant-kms`](modules/tenant-kms/)

Manages per-tenant KMS Customer Managed Keys with strict key policies ensuring only the owning tenant can use the key for encryption/decryption operations.

**Key policy principles:**
- Platform admins can manage keys but cannot use them for data operations
- Only the tenant's IAM workload role can perform `kms:Decrypt` and `kms:GenerateDataKey`
- Automatic annual key rotation enabled
- 30-day deletion window supports GDPR right-to-erasure

---

### [`network-isolation`](modules/network-isolation/)

Establishes network-level tenant isolation with defense-in-depth.

**Creates:** VPC, private subnets (multi-AZ), NAT Gateway, VPC endpoints (S3, EC2, SSM), default-deny security groups, NACLs, VPC Flow Logs.

---

## 🚀 Quick Start

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- AWS Organizations configured
- Python 3.8+ (for validation scripts)

### Deploy a Single Tenant

```bash
cd examples/basic-tenant
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Deploy the Full Multi-Tenant Platform

```bash
cd examples/full-platform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

---

## 📊 Compliance Coverage

### SOC 2 Trust Services Criteria

| Criteria | Control | Status |
|---|---|---|
| CC6.1 | IAM least privilege, MFA enforcement | ✅ |
| CC6.6 | KMS encryption at rest, TLS in transit | ✅ |
| CC6.7 | AWS Config drift detection, IaC | ✅ |
| CC7.2 | GuardDuty + Security Hub monitoring | ✅ |

### CIS AWS Foundations Benchmark

| Section | Description | Status |
|---|---|---|
| 1.x | IAM policies, password policies, MFA | ✅ |
| 2.x | CloudTrail, log file validation | ✅ |
| 3.x | CloudWatch alerting | ✅ |
| 4.x | Network security baseline | ✅ |

Generate a compliance report:

```bash
python scripts/generate_compliance_report.py \
  --accounts tenant-a,tenant-b \
  --framework soc2 \
  --output report.html
```

---

## 🧪 Validation

```bash
# Check Terraform formatting
terraform fmt -check -recursive

# Validate module configuration
cd modules/tenant-account && terraform init -backend=false && terraform validate

# Test tenant isolation controls
python scripts/validate_isolation.py \
  --tenant-a-role arn:aws:iam::111111111111:role/tenant-a-workload-role \
  --tenant-b-bucket tenant-b-data-bucket
```

---

## 📚 Documentation

- [Architecture Decisions](docs/ARCHITECTURE.md) — Design rationale and trade-offs
- [Security Controls](docs/SECURITY.md) — Detailed security implementation
- [Compliance Mapping](docs/COMPLIANCE.md) — Framework alignment

---

## 👤 Author

**Ankita Dixit** — Cloud Security Engineer, Amazon Web Services

5+ years securing AWS environments at scale — IAM architecture, multi-account security frameworks, threat detection, and compliance automation across 50+ organizational accounts.

**Certifications:** AWS Certified Security – Specialty · AWS Certified Solutions Architect – Professional · AWS Certified Advanced Networking – Specialty · HashiCorp Terraform Associate · IAM Subject Matter Expert

- 🐙 GitHub: [@master-coder1998](https://github.com/master-coder1998)
- 💼 LinkedIn: [ankita-dixit-8892b8185](https://www.linkedin.com/in/ankita-dixit-8892b8185/)

---

## 📄 License

[MIT](LICENSE) — free to use and adapt.
