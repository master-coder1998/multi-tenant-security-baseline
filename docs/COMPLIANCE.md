# Compliance Mapping

## SOC 2 Trust Services Criteria

| Criteria | Control | Implementation |
|---|---|---|
| **CC6.1** — Logical Access Controls | IAM least privilege, MFA enforcement | Per-tenant IAM workload roles; SCPs enforce MFA for console access |
| **CC6.6** — Encryption | Encryption at rest and in transit | Per-tenant KMS CMKs; TLS 1.2+ enforced; S3 rejects unencrypted uploads |
| **CC6.7** — Config Change Detection | Immutable audit trail; drift detection | CloudTrail with log file validation; AWS Config continuous evaluation |
| **CC7.2** — Security Monitoring | Threat detection; alerting | GuardDuty aggregated; Security Hub dashboards; SNS/EventBridge alerts |
| **CC8.1** — Change Management | Infrastructure as Code | 100% Terraform; no manual console changes; CI validates all PRs |
| **A1.2** — Availability | Multi-AZ deployment | Private subnets across ≥2 AZs; Multi-AZ RDS |

## CIS AWS Foundations Benchmark v1.5

| Section | Rule | Status |
|---|---|---|
| 1.4 | Root account MFA enabled | ✅ (SCP enforcement) |
| 1.5 | IAM password policy configured | ✅ (Config rule) |
| 1.14 | Access keys rotated within 90 days | ✅ (Config rule alert) |
| 2.1 | CloudTrail enabled in all regions | ✅ (Organization trail) |
| 2.2 | CloudTrail log file validation enabled | ✅ (Terraform config) |
| 2.3 | CloudTrail logs stored in dedicated S3 | ✅ (Security account S3) |
| 2.4 | CloudTrail logs integrated with CloudWatch | ✅ (Log group + alarms) |
| 3.1–3.14 | CloudWatch alarms for critical API calls | ✅ (EventBridge rules) |
| 4.1 | No security groups allow unrestricted SSH/RDP | ✅ (Default-deny SG) |
| 4.2 | No security groups allow unrestricted 0.0.0.0/0 | ✅ (Config rule) |

## GDPR Article Mapping

| Requirement | Implementation |
|---|---|
| Art. 17 — Right to erasure | Delete tenant KMS CMK → renders all encrypted data unrecoverable |
| Art. 25 — Data protection by design | Encryption by default; private-only networking; least-privilege access |
| Art. 30 — Records of processing | CloudTrail audit log; per-tenant S3 access logs |
| Art. 32 — Security of processing | KMS encryption; TLS in transit; GuardDuty monitoring |

## Generating Evidence for Audits

AWS Config stores a history of compliance evaluations. Use the compliance report script to produce a point-in-time snapshot for your auditors:

```bash
python scripts/generate_compliance_report.py \
  --accounts 111111111111,222222222222 \
  --framework soc2 \
  --region us-east-1 \
  --output soc2_evidence.html
```

GuardDuty and Security Hub findings can be exported from the AWS Console or via the AWS CLI for inclusion in audit artefact packages.
