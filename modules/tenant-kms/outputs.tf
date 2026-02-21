output "key_id" {
  value = aws_kms_key.tenant.id
}

output "key_arn" {
  value = aws_kms_key.tenant.arn
}

output "alias_name" {
  value = aws_kms_alias.tenant.name
}
