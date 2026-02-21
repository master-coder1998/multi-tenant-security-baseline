# Architecture Decisions

## Tenant Isolation Strategy

### Why Separate AWS Accounts?

Each tenant is provisioned into a dedicated AWS account rather than using VPC isolation, resource tagging, or IAM-based separation within a shared account.

**Rationale:**

AWS accounts are the strongest isolation boundary the platform provides. IAM policies, SCPs, and VPC configurations cannot be misconfigured in ways that allow cross-account data access without an explicit trust relationship — whereas IAM complexity in a shared account is a perennial source of over-permissioned access.

Practical benefits include:
- Blast radius is contained to a single account. A compromised tenant credential cannot reach another tenant's data.
- Independent billing enables per-tenant cost attribution.
- Compliance scope is cleaner — auditors can inspect a single account as the data boundary.
- Least-privilege IAM is simpler when there is no need for tenant-scoping conditions on every policy statement.

**Trade-offs acknowledged:**
- More accounts to manage, mitigated by AWS Organizations and automation.
- Cross-account access for shared services adds role assumption overhead.
- Some AWS services have per-account charges (Security Hub, Config).

**Alternatives considered:**
- Single-account, VPC-per-tenant — rejected due to IAM complexity for multi-tenant RBAC.
- Single-account with resource tagging — rejected due to weak isolation guarantees.

---

## KMS Key Per Tenant

Each tenant receives a dedicated KMS Customer Managed Key (CMK). The key policy ensures that only the tenant's workload IAM role can perform data operations (`kms:Decrypt`, `kms:GenerateDataKey`). Platform admins can manage keys but cannot use them for decryption.

**Rationale:**
- Enforces cryptographic data isolation: Tenant A's role cannot decrypt Tenant B's data.
- Supports GDPR right to erasure: deleting a KMS key makes all data encrypted with it unrecoverable without destroying the data itself.
- CloudTrail logs every key usage, providing a complete audit trail of who accessed which tenant's data and when.

---

## Network Architecture

### No VPC Peering Between Tenants

Tenant VPCs are intentionally isolated with no peering connections. Shared services (e.g., internal DNS) are accessed via PrivateLink, which creates a one-way connection that does not expose the shared service's VPC to the tenant.

**Rationale:** Prevents lateral movement. If a workload in Tenant A is compromised, the attacker cannot pivot to Tenant B's network.

### Private Subnets Only

All tenant workloads run in private subnets with no direct internet inbound access. Egress goes through a NAT Gateway (for internet-bound traffic) or VPC endpoints (for AWS service traffic).

**Rationale:** Minimises internet exposure surface. VPC endpoints keep AWS API calls on the AWS backbone and avoid internet egress entirely for services like S3, SSM, and CloudWatch.

---

## Centralized Security Account

GuardDuty, Security Hub, and CloudTrail aggregate into a dedicated security account that tenant workload accounts cannot modify.

**Rationale:**
- Tenants cannot disable monitoring in their own accounts.
- Security team gets a single pane of glass across all tenants.
- Incident response can correlate events across tenants without hopping between accounts.
- One Security Hub aggregator is more cost-effective than N individual subscriptions.

**Access model:**
- Security team: read-only cross-account access to all tenant accounts.
- Incident response: limited write access (e.g., isolate compromised instances).
- All security account access is logged and alerted.

---

## Compliance Automation

AWS Config rules run continuously in every tenant account and report compliance status to the security account aggregator. Findings are surfaced in Security Hub and trigger EventBridge rules for automated remediation where appropriate.

This provides continuous validation rather than point-in-time audits, generates evidence artefacts suitable for SOC 2 auditors, and detects configuration drift immediately rather than at the next scheduled scan.

---

## Resource Sharing vs Per-Tenant Isolation

| Resource | Strategy | Rationale |
|---|---|---|
| VPC | Per-tenant | Network isolation |
| KMS CMK | Per-tenant | Cryptographic data isolation |
| GuardDuty | Centralized master | Cost efficiency + unified visibility |
| Security Hub | Centralized aggregator | Cost efficiency + unified findings |
| CloudTrail | Organization trail | Single consistent audit log |
| NAT Gateway | Per-tenant | Network isolation |
| Transit Gateway | Shared (to shared services) | Controlled access to shared infra |

---

## Author

**Ankita Dixit** — Cloud Security Engineer  
GitHub: [@master-coder1998](https://github.com/master-coder1998) | LinkedIn: [ankita-dixit-8892b8185](https://www.linkedin.com/in/ankita-dixit-8892b8185/)
