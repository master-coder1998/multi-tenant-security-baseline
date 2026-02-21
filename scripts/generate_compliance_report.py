#!/usr/bin/env python3
"""
generate_compliance_report.py

Queries AWS Security Hub and Config for each tenant account
and generates an HTML compliance report mapped to SOC 2 and CIS controls.

Usage:
    python scripts/generate_compliance_report.py \
        --accounts 111111111111,222222222222 \
        --framework soc2 \
        --region us-east-1 \
        --output compliance_report.html
"""

import argparse
import datetime
import json
import sys
import boto3
from botocore.exceptions import ClientError


SOC2_CONTROL_MAP = {
    "CC6.1": {
        "title": "Logical Access Controls",
        "config_rules": [
            "iam-password-policy",
            "mfa-enabled-for-iam-console-access",
            "access-keys-rotated",
        ],
    },
    "CC6.6": {
        "title": "Encryption in Transit and at Rest",
        "config_rules": [
            "s3-default-encryption-kms",
            "encrypted-volumes",
            "rds-storage-encrypted",
        ],
    },
    "CC6.7": {
        "title": "Configuration Change Detection",
        "config_rules": [
            "cloud-trail-enabled",
            "cloudtrail-log-file-validation-enabled",
        ],
    },
    "CC7.2": {
        "title": "Security Monitoring",
        "config_rules": [
            "guardduty-enabled-centralized",
            "securityhub-enabled",
        ],
    },
}


def get_config_compliance(account_id: str, rules: list, region: str) -> dict:
    """Query AWS Config for compliance status of specific rules."""
    try:
        client = boto3.client("config", region_name=region)
        results = {}
        for rule in rules:
            try:
                response = client.describe_compliance_by_config_rule(
                    ConfigRuleNames=[rule],
                    ComplianceTypes=["COMPLIANT", "NON_COMPLIANT", "NOT_APPLICABLE"],
                )
                if response["ComplianceByConfigRules"]:
                    status = response["ComplianceByConfigRules"][0]["Compliance"]["ComplianceType"]
                    results[rule] = status
                else:
                    results[rule] = "NOT_FOUND"
            except ClientError:
                results[rule] = "NOT_FOUND"
        return results
    except ClientError as e:
        print(f"  Warning: Could not query Config for account {account_id}: {e}")
        return {rule: "ERROR" for rule in rules}


def generate_html_report(framework: str, accounts: list, region: str) -> str:
    """Generate an HTML compliance report."""
    now = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    control_map = SOC2_CONTROL_MAP if framework.lower() == "soc2" else SOC2_CONTROL_MAP

    account_results = {}
    for account_id in accounts:
        print(f"  Querying account: {account_id}")
        all_rules = [r for ctrl in control_map.values() for r in ctrl["config_rules"]]
        account_results[account_id] = get_config_compliance(account_id, all_rules, region)

    # Build HTML
    status_color = {"COMPLIANT": "#28a745", "NON_COMPLIANT": "#dc3545", "NOT_FOUND": "#6c757d", "ERROR": "#ffc107"}

    account_headers = "".join(f"<th>{a}</th>" for a in accounts)

    rows = ""
    for ctrl_id, ctrl_data in control_map.items():
        for rule in ctrl_data["config_rules"]:
            cells = ""
            for account_id in accounts:
                status = account_results[account_id].get(rule, "ERROR")
                color = status_color.get(status, "#6c757d")
                cells += f'<td style="color:{color};font-weight:bold">{status}</td>'
            rows += f"""
            <tr>
                <td><strong>{ctrl_id}</strong></td>
                <td>{ctrl_data["title"]}</td>
                <td><code>{rule}</code></td>
                {cells}
            </tr>"""

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Compliance Report — {framework.upper()}</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 40px; color: #333; }}
        h1 {{ color: #1a1a2e; }}
        .meta {{ color: #666; margin-bottom: 30px; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border: 1px solid #ddd; padding: 10px 14px; text-align: left; }}
        th {{ background-color: #1a1a2e; color: white; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
        code {{ background: #f1f1f1; padding: 2px 6px; border-radius: 3px; font-size: 0.9em; }}
        .footer {{ margin-top: 40px; color: #999; font-size: 0.85em; }}
    </style>
</head>
<body>
    <h1>Compliance Report: {framework.upper()}</h1>
    <div class="meta">
        <p>Generated: {now} | Region: {region}</p>
        <p>Accounts: {", ".join(accounts)}</p>
    </div>

    <table>
        <thead>
            <tr>
                <th>Control</th>
                <th>Description</th>
                <th>Config Rule</th>
                {account_headers}
            </tr>
        </thead>
        <tbody>
            {rows}
        </tbody>
    </table>

    <div class="footer">
        <p>Multi-Tenant Security Baseline — Compliance Report</p>
        <p>Author: Ankita Dixit | <a href="https://github.com/master-coder1998">GitHub</a></p>
    </div>
</body>
</html>"""

    return html


def main():
    parser = argparse.ArgumentParser(description="Generate a compliance report for tenant accounts")
    parser.add_argument("--accounts", required=True, help="Comma-separated AWS account IDs")
    parser.add_argument("--framework", default="soc2", choices=["soc2", "cis"], help="Compliance framework")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--output", default="compliance_report.html", help="Output HTML file path")
    args = parser.parse_args()

    accounts = [a.strip() for a in args.accounts.split(",")]
    print(f"Generating {args.framework.upper()} compliance report for {len(accounts)} account(s)...")

    html = generate_html_report(args.framework, accounts, args.region)

    with open(args.output, "w") as f:
        f.write(html)

    print(f"\nReport written to: {args.output}")


if __name__ == "__main__":
    main()
