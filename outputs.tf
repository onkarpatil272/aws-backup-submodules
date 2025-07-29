# Backup Vault Outputs

output "vault_id" {
  description = "The name of the backup vault"
  value       = try(values(aws_backup_vault.backup_vault)[0].id, null)
}

output "vault_arn" {
  description = "The ARN of the backup vault"
  value       = try(values(aws_backup_vault.backup_vault)[0].arn, null)
}

output "vault_recovery_points" {
  description = "The number of recovery points stored in the backup vault"
  value       = try(values(aws_backup_vault.backup_vault)[0].recovery_points, null)
}

# Backup Plan Outputs

output "plan_id" {
  description = "The id of the backup plan"
  value       = try(values(aws_backup_plan.backup_plan)[0].id, null)
}

output "plan_arn" {
  description = "The ARN of the backup plan"
  value       = try(values(aws_backup_plan.backup_plan)[0].arn, null)
}

output "plan_version" {
  description = "Version ID of the backup plan"
  value       = try(values(aws_backup_plan.backup_plan)[0].version, null)
}

output "plans" {
  description = "Map of backup plans created"
  value = {
    for k, v in aws_backup_plan.backup_plan : k => {
      id      = v.id
      arn     = v.arn
      version = v.version
    }
  }
}

output "plan_role" {
  description = "The service role used by the backup plan"
  value       = var.iam_role_arn
}

output "vault_kms_key_arn" {
  description = "The server-side encryption key used for vault"
  value       = try(values(aws_backup_vault.backup_vault)[0].kms_key_arn, null)
}

output "vault_lock_configuration" {
  description = "The backup vault lock configuration"
  value = var.enabled && local.should_create_lock ? {
    min_retention_days  = aws_backup_vault_lock_configuration.ab_vault_lock[0].min_retention_days
    max_retention_days  = aws_backup_vault_lock_configuration.ab_vault_lock[0].max_retention_days
    changeable_for_days = aws_backup_vault_lock_configuration.ab_vault_lock[0].changeable_for_days
  } : null
}

output "backup_selection_ids" {
  description = "Map of backup selection IDs"
  value = {
    for k, v in aws_backup_selection.ab_selection : k => v.id
  }
}

output "backup_vault_arn" {
  description = "Alias output for backup vault ARN"
  value       = try(values(aws_backup_vault.backup_vault)[0].arn, null)
}

output "backup_plan_ids" {
  description = "List of backup plan IDs"
  value       = [for plan in values(aws_backup_plan.backup_plan) : plan.id]
}

output "sns_topic_arns" {
  description = "Map of SNS topic ARNs used for backup notifications"
  value       = local.sns_topic_arns
}
