# Backup Vault Outputs

output "vaults" {
  description = "Map of all backup vaults created"
  value = {
    for k, v in aws_backup_vault.backup_vault : k => {
      id                = v.id
      arn               = v.arn
      name              = v.name
      recovery_points   = v.recovery_points
      kms_key_arn       = v.kms_key_arn
      tags              = v.tags
    }
  }
}

# Backup Plan Outputs

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

output "vault_lock_configurations" {
  description = "Map of vault lock configurations for all backup vaults"
  value = {
    for k, v in aws_backup_vault_lock_configuration.ab_vault_lock :
    k => {
      min_retention_days  = v.min_retention_days
      max_retention_days  = v.max_retention_days
      changeable_for_days = v.changeable_for_days
    }
  }
}

output "backup_selection_ids" {
  description = "Map of backup selection IDs"
  value = {
    for k, v in aws_backup_selection.ab_selection : k => v.id
  }
}

output "backup_plan_ids" {
  description = "List of backup plan IDs"
  value       = [for plan in values(aws_backup_plan.backup_plan) : plan.id]
}

output "sns_topic_arns" {
  description = "Map of SNS topic ARNs used for backup notifications"
  value       = local.sns_topic_arns
}

output "plan_selections_map" {
  value = local.plan_selections_map
}