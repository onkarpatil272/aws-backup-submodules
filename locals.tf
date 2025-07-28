locals {
  # Validation: error if copy_action blocks are defined but enable_copy_action is false
  copy_action_validation_error = !local.enable_copy_action && anytrue([
    for rule in var.rules : length(try(rule.copy_action, [])) > 0
  ]) ? "Error: 'copy_action' blocks are defined in rules, but enable_copy_action is false. Please check your configuration." : null
  # Basic flags
  should_create_vault       = var.enabled && var.vault_name != null
  should_create_lock        = local.should_create_vault && var.locked
  should_create_legacy_plan = var.enabled && length(var.plans) == 0 && length(var.rules) > 0

  backup_alarm_metric_map = {
    BACKUP_JOB      = "BackupJobsFailed"
    COPY_JOB        = "CopyJobsFailed"
    RESTORE_JOB     = "RestoreJobsFailed"
    REPLICATION_JOB = "ReplicationJobsFailed"
  }
  # Process lifecycle rules
  processed_rules = [
    for rule in var.rules : merge(rule, {
      lifecycle = merge(
        {
          cold_storage_after = var.default_lifecycle_cold_storage_after_days
          delete_after       = var.default_lifecycle_delete_after_days
        },
        try(rule.lifecycle, {})
      )
    })
  ]

  # Check if any copy_action is defined
  enable_copy_action = anytrue([
    for rule in var.rules : length(try(rule.copy_action, [])) > 0
  ])

  # Legacy plan block
  legacy_plan = local.should_create_legacy_plan ? [{
    name       = "legacy-backup-plan"
    rules      = local.processed_rules
    selections = var.selections
  }] : []

  # Combine legacy and provided plans
  all_plans = concat(var.plans, local.legacy_plan)

  # Create a map of plans with default names if missing
  plans_map = {
    for idx, plan in local.all_plans :
    plan.name != null ? plan.name : "plan-${idx}" => {
      name       = plan.name != null ? plan.name : "plan-${idx}"
      rules      = plan.rules
      selections = try(plan.selections, {})
    }
  }

  # Flatten selections into a map
  plan_selections_map = merge([
    for plan_name, plan in local.plans_map :
    plan.selections != null ? {
      for sel_name, selection in plan.selections :
      "${plan_name}-${sel_name}" => {
        plan_key      = plan_name
        selection_key = sel_name
        selection     = selection
      }
    } : {}
  ]...)

  # KMS key ARN fallback logic
  kms_key_arn = coalesce(
    var.kms_key_arn,
    length(data.aws_kms_key.backup) > 0 ? data.aws_kms_key.backup[0].arn : null
  )

  # Tags
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "terraform"
      Component = "aws-backup"
    }
  )

  backup_plan_tags = merge(local.common_tags, var.backup_plan_tags)
  vault_tags       = merge(local.common_tags, var.vault_tags)
}
