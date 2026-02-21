# modules/tenant-account/outputs.tf

output "vpc_id" {
  description = "ID of the tenant VPC"
  value       = aws_vpc.tenant.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (multi-AZ)"
  value       = aws_subnet.private[*].id
}

output "kms_key_id" {
  description = "ID of the tenant CMK"
  value       = aws_kms_key.tenant.id
}

output "kms_key_arn" {
  description = "ARN of the tenant CMK"
  value       = aws_kms_key.tenant.arn
}

output "kms_alias" {
  description = "Alias of the tenant CMK"
  value       = aws_kms_alias.tenant.name
}

output "s3_bucket_name" {
  description = "Name of the tenant S3 data bucket"
  value       = aws_s3_bucket.tenant.id
}

output "s3_bucket_arn" {
  description = "ARN of the tenant S3 data bucket"
  value       = aws_s3_bucket.tenant.arn
}

output "workload_role_arn" {
  description = "ARN of the tenant workload IAM role"
  value       = aws_iam_role.tenant_workload.arn
}

output "workload_role_name" {
  description = "Name of the tenant workload IAM role"
  value       = aws_iam_role.tenant_workload.name
}

output "log_group_name" {
  description = "Name of the tenant CloudWatch log group"
  value       = aws_cloudwatch_log_group.tenant.name
}

output "security_group_id" {
  description = "ID of the tenant default security group"
  value       = aws_security_group.tenant_default.id
}
