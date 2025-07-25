locals {
  should_create_vault       = var.enabled && var.vault_name != null
  should_create_lock        = local.should_create_vault && var.locked
  should_create_legacy_plan = var.enabled && length(var.plans) == 0 && length(var.rules) > 0


  processed_rules = [for rule in var.rules : merge(rule, {
    lifecycle = merge(
      {
        cold_storage_after = var.default_lifecycle_cold_storage_after_days
        delete_after       = var.default_lifecycle_delete_after_days
      },
      try(rule.lifecycle, {})
    )
  })]

  # Create legacy plan if needed
  legacy_plan = local.should_create_legacy_plan ? [{
    name       = "legacy-backup-plan"
    rules      = local.processed_rules
    selections = var.selections
  }] : []

  # Combine legacy and explicit plans
  all_plans = concat(var.plans, local.legacy_plan)

  plans_map = { for idx, plan in local.all_plans :
    plan.name != null ? plan.name : "plan-${idx}" => {
      name       = plan.name != null ? plan.name : "plan-${idx}"
      rules      = plan.rules
      selections = try(plan.selections, {})
    }
  }

  plan_selections_map = merge([
    for plan_name, plan in local.plans_map :
    { for sel_name, selection in plan.selections :
      "${plan_name}-${sel_name}" => {
        plan_key      = plan_name
        selection_key = sel_name
        selection     = selection
      }
    }
  ]...)

  # Works for a single data source instance
  kms_key_arn = coalesce(var.kms_key_arn, try(data.aws_kms_key.backup.arn, null))

  # — OR — if the data source is behind `for_each`, pick the first/only element:
  # kms_key_arn = coalesce(
  #   var.kms_key_arn,
  #   try(one(values(data.aws_kms_key.backup)).arn, null)
  # )

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

