#!/usr/bin/env python3
"""
validate_isolation.py

Tests that tenant isolation controls are functioning correctly.
Verifies that Tenant A cannot access Tenant B's S3 data or KMS key,
even when authenticated as Tenant A's workload role.

Usage:
    python scripts/validate_isolation.py \
        --tenant-a-role arn:aws:iam::111111111111:role/tenant-a-workload-role \
        --tenant-b-bucket tenant-b-data-bucket \
        --tenant-b-key-arn arn:aws:kms:us-east-1:222222222222:key/...
"""

import argparse
import sys
import boto3
from botocore.exceptions import ClientError


PASS = "\033[92m  ✅ PASSED\033[0m"
FAIL = "\033[91m  ❌ FAILED\033[0m"
WARN = "\033[93m  ⚠️  WARNING\033[0m"


def assume_role(role_arn: str, session_name: str = "isolation-test") -> dict:
    """Assume a role and return temporary credentials."""
    sts = boto3.client("sts")
    response = sts.assume_role(RoleArn=role_arn, RoleSessionName=session_name)
    return response["Credentials"]


def get_client_with_creds(service: str, region: str, creds: dict):
    """Create a boto3 client using temporary credentials."""
    return boto3.client(
        service,
        region_name=region,
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
    )


def test_cross_tenant_s3_read(tenant_a_creds: dict, tenant_b_bucket: str, region: str) -> bool:
    """Tenant A must NOT be able to list or read Tenant B's S3 bucket."""
    print(f"\n[TEST] Cross-tenant S3 read: attempting to list objects in '{tenant_b_bucket}'")
    s3 = get_client_with_creds("s3", region, tenant_a_creds)

    try:
        s3.list_objects_v2(Bucket=tenant_b_bucket)
        print(f"{FAIL}: Tenant A successfully listed Tenant B's bucket — isolation is broken!")
        return False
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("AccessDenied", "403"):
            print(f"{PASS}: Access denied as expected (code: {code})")
            return True
        elif code == "NoSuchBucket":
            print(f"{WARN}: Bucket does not exist. Check bucket name and try again.")
            return False
        else:
            print(f"{WARN}: Unexpected error — {e}")
            return False


def test_cross_tenant_s3_write(tenant_a_creds: dict, tenant_b_bucket: str, region: str) -> bool:
    """Tenant A must NOT be able to write to Tenant B's S3 bucket."""
    print(f"\n[TEST] Cross-tenant S3 write: attempting to put object in '{tenant_b_bucket}'")
    s3 = get_client_with_creds("s3", region, tenant_a_creds)

    try:
        s3.put_object(Bucket=tenant_b_bucket, Key="isolation-test.txt", Body=b"test")
        print(f"{FAIL}: Tenant A successfully wrote to Tenant B's bucket — isolation is broken!")
        return False
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("AccessDenied", "403"):
            print(f"{PASS}: Write denied as expected (code: {code})")
            return True
        else:
            print(f"{WARN}: Unexpected error — {e}")
            return False


def test_cross_tenant_kms(tenant_a_creds: dict, tenant_b_key_arn: str, region: str) -> bool:
    """Tenant A must NOT be able to use Tenant B's KMS key."""
    print(f"\n[TEST] Cross-tenant KMS: attempting to generate data key using '{tenant_b_key_arn}'")
    kms = get_client_with_creds("kms", region, tenant_a_creds)

    try:
        kms.generate_data_key(KeyId=tenant_b_key_arn, KeySpec="AES_256")
        print(f"{FAIL}: Tenant A successfully used Tenant B's KMS key — isolation is broken!")
        return False
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("AccessDeniedException", "AccessDenied", "403"):
            print(f"{PASS}: KMS access denied as expected (code: {code})")
            return True
        elif code == "NotFoundException":
            print(f"{WARN}: KMS key not found. Check the key ARN.")
            return False
        else:
            print(f"{WARN}: Unexpected error — {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description="Validate multi-tenant isolation controls")
    parser.add_argument("--tenant-a-role", required=True, help="ARN of Tenant A workload role")
    parser.add_argument("--tenant-b-bucket", default="", help="Tenant B S3 bucket name")
    parser.add_argument("--tenant-b-key-arn", default="", help="Tenant B KMS key ARN")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    args = parser.parse_args()

    print("=" * 65)
    print("  Multi-Tenant Isolation Validation")
    print("=" * 65)
    print(f"  Tenant A Role : {args.tenant_a_role}")
    print(f"  Target Region : {args.region}")
    print("=" * 65)

    try:
        print("\nAssuming Tenant A workload role...")
        creds = assume_role(args.tenant_a_role)
        print("  Role assumed successfully")
    except ClientError as e:
        print(f"\n  ERROR: Could not assume Tenant A role: {e}")
        sys.exit(1)

    results = []

    if args.tenant_b_bucket:
        results.append(test_cross_tenant_s3_read(creds, args.tenant_b_bucket, args.region))
        results.append(test_cross_tenant_s3_write(creds, args.tenant_b_bucket, args.region))
    else:
        print("\n  (Skipping S3 tests — no --tenant-b-bucket provided)")

    if args.tenant_b_key_arn:
        results.append(test_cross_tenant_kms(creds, args.tenant_b_key_arn, args.region))
    else:
        print("  (Skipping KMS tests — no --tenant-b-key-arn provided)")

    print("\n" + "=" * 65)
    passed = sum(results)
    total = len(results)

    if total == 0:
        print("  No tests were run. Provide --tenant-b-bucket and/or --tenant-b-key-arn.")
        sys.exit(1)

    print(f"  Results: {passed}/{total} isolation tests passed")

    if passed == total:
        print("\033[92m  All isolation controls are functioning correctly.\033[0m")
    else:
        print("\033[91m  WARNING: Some isolation controls may be misconfigured!\033[0m")

    print("=" * 65)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
