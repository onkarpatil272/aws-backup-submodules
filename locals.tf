locals {
  # Check if any copy_action is defined in both rules and plans
  enable_copy_action = anytrue(concat(
    [for rule in var.rules : try(rule.copy_action, null) != null && try(length(rule.copy_action), 0) > 0],
    flatten([for plan in var.plans : [for rule in plan.rules : try(rule.copy_action, null) != null && try(length(rule.copy_action), 0) > 0]])
  ))

  # Basic flags
  should_create_vaults      = var.enabled && length(var.vaults) > 0
  should_create_locks       = local.should_create_vaults && anytrue([for vault in var.vaults : try(vault.locked, false)])
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

  # Get the first plan name for fallback
  first_plan_name = length(var.plans) > 0 ? (var.plans[0].name != null ? var.plans[0].name : "plan-0") : "legacy-backup-plan"

  # Flatten selections into a map: plan selections + global selections
  plan_selections_map = merge(
    merge([
      for plan_name, plan in local.plans_map :
      plan.selections != null ? {
        for sel_name, selection in plan.selections :
        "${plan_name}-${sel_name}" => {
          plan_key      = plan_name
          selection_key = sel_name
          selection     = selection
        }
      } : {}
    ]...),
    var.selections != null && length(var.selections) > 0 ? {
      for sel_name, selection in var.selections :
      "default-${sel_name}" => {
        plan_key      = local.first_plan_name
        selection_key = sel_name
        selection     = selection
      }
    } : {}
  )

  # Process vaults with defaults and common tags
  vaults_map = {
    for k, v in var.vaults :
    k => {
      name                = v.name
      kms_key_arn         = try(v.kms_key_arn, null)
      tags                = merge(local.common_tags, try(v.tags, {}))
      locked              = try(v.locked, false)
      min_retention_days  = try(v.min_retention_days, null)
      max_retention_days  = try(v.max_retention_days, null)
      changeable_for_days = try(v.changeable_for_days, null)
    }
  }

  # KMS key ARN fallback logic for each vault
  vault_kms_keys = {
    for vault_key, vault_config in local.vaults_map :
    vault_key => coalesce(
      vault_config.kms_key_arn,
      length(data.aws_kms_key.backup) > 0 ? data.aws_kms_key.backup[0].arn : null
    )
  }

  # Tags
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "terraform"
      Component = "aws-backup"
    }
  )

  backup_plan_tags = merge(local.common_tags, var.backup_plan_tags)

  sns_topic_arns = {
    for k, v in var.notifications : k => (
      try(v.sns_topic_arn, null) != null ? v.sns_topic_arn :
      try(aws_sns_topic.this[k].arn, null)
    )
    if try(v.enabled, false)
  }
}