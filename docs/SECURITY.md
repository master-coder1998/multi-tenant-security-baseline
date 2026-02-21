# Security Controls

## Defense in Depth

This architecture implements security controls at every layer, so that no single misconfiguration creates a complete breach.

### Layer 1: Account Isolation

AWS accounts serve as the primary isolation boundary. SCPs (Service Control Policies) applied at the Organization level enforce guardrails that cannot be overridden by any IAM policy within a tenant account.

Example SCPs enforced:
- Deny disabling CloudTrail
- Deny disabling GuardDuty
- Deny creating IAM users (all access must go through IAM roles)
- Restrict deployments to approved AWS regions

### Layer 2: Identity and Access

IAM least privilege is enforced through: workload roles scoped to tenant-owned resources only, permission boundaries preventing privilege escalation, and condition keys in key policies restricting encryption operations to the owning tenant.

No long-lived IAM credentials exist in tenant accounts. All access uses IAM roles with time-limited session tokens.

### Layer 3: Network

Tenant workloads operate exclusively in private subnets. There is no internet ingress. All inbound traffic enters through an Application Load Balancer in a separate subnet. Security groups default to deny-all ingress; rules are added explicitly and reviewed in code review.

VPC endpoints remove the need to traverse the internet for AWS API calls, reducing the attack surface.

### Layer 4: Data

Every data store uses KMS encryption at rest with a per-tenant CMK. TLS 1.2+ is enforced for all in-transit connections. S3 bucket policies reject unencrypted uploads.

### Layer 5: Monitoring and Detection

GuardDuty performs continuous threat detection across all tenant accounts, analysing CloudTrail logs, VPC Flow Logs, and DNS query logs. Findings are aggregated to the security account. HIGH severity findings trigger immediate SNS alerts.

Security Hub aggregates compliance findings from GuardDuty, Config, and Inspector into a unified dashboard. All findings are mapped to security standards (CIS, SOC 2).

---

## Threat Model

| Threat | Mitigation |
|---|---|
| Compromised tenant credentials | Account isolation prevents lateral movement; KMS key policies prevent cross-tenant data access |
| Data breach | Per-tenant CMK encryption; S3 bucket policies reject public access and unencrypted uploads |
| Insider threat | Centralized logging in tamper-resistant security account; IAM least privilege; all access audited |
| Configuration drift | AWS Config continuous monitoring; EventBridge automated remediation |
| Privilege escalation | IAM permission boundaries; SCPs prevent IAM user creation |
| DDoS | AWS Shield Standard (automatic); ALB rate limiting |

---

## Incident Response Runbook

**Detection:** GuardDuty HIGH finding → EventBridge rule → SNS alert to security team.

**Containment:** Apply SCP to deny all API calls except read operations in the affected account. Revoke active IAM sessions. Take EBS snapshots for forensic analysis.

**Recovery:** Restore from backup. Rotate all credentials (access keys, secrets). Deploy clean infrastructure from Terraform.

**Post-incident:** Root cause analysis → update Terraform modules → team retrospective.

---

## Author

**Ankita Dixit** — Cloud Security Engineer  
GitHub: [@master-coder1998](https://github.com/master-coder1998) | LinkedIn: [ankita-dixit-8892b8185](https://www.linkedin.com/in/ankita-dixit-8892b8185/)
