data "aws_partition" "current" {}

data "aws_kms_key" "backup" {
  count  = var.enabled && var.kms_key_arn == null ? 1 : 0
  key_id = "alias/aws/backup"
}

locals {
  should_create_vault       = var.enabled && var.vault_name != null
  should_create_lock        = local.should_create_vault && var.locked
  should_create_legacy_plan = var.enabled && length(var.plans) == 0 && length(var.rules) > 0

  enable_copy_action = var.cross_region_vault_arn != null
  vault_lock_requirements_met = var.min_retention_days != null && var.max_retention_days != null
  retention_days_valid        = local.vault_lock_requirements_met ? var.min_retention_days <= var.max_retention_days : true
  check_retention_days        = var.locked ? (local.vault_lock_requirements_met && local.retention_days_valid) : true

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

  all_selection_resources = distinct(concat(
    var.selection_resources,
    flatten([for sel in var.selections : try(sel.resources, [])])
  ))

  normalized_selections = { for sel_name, sel in var.selections :
    sel_name => {
      resources      = try(sel.resources, [])
      not_resources  = try(sel.not_resources, [])
      conditions     = try(sel.conditions, {})
      selection_tags = try(sel.selection_tags, [])
    }
  }

  kms_key_arn = coalesce(var.kms_key_arn, try(data.aws_kms_key.backup[0].arn, null))

  lifecycle_validations = alltrue([
    for rule in local.processed_rules : (
      length(try(rule.lifecycle, {})) == 0 ? true : (
        (try(rule.lifecycle.cold_storage_after, null) == null || try(rule.lifecycle.delete_after, null) == null) ? true :
        coalesce(rule.lifecycle.cold_storage_after, 0) <= coalesce(rule.lifecycle.delete_after, var.default_lifecycle_delete_after_days)
      )
    )
    ]) && alltrue(flatten([
      for plan in var.plans : [
        for rule in plan.rules : (
          length(try(rule.lifecycle, {})) == 0 ? true : (
            (try(rule.lifecycle.cold_storage_after, null) == null || try(rule.lifecycle.delete_after, null) == null) ? true :
            coalesce(rule.lifecycle.cold_storage_after, 0) <= coalesce(rule.lifecycle.delete_after, var.default_lifecycle_delete_after_days)
          )
        )
      ]
  ]))
}

resource "aws_backup_vault" "backup_vault" {
  count       = local.should_create_vault ? 1 : 0
  name        = var.vault_name
  kms_key_arn = local.kms_key_arn
  tags        = var.tags
}

resource "aws_backup_vault_lock_configuration" "ab_vault_lock" {
  count               = local.should_create_lock && local.check_retention_days ? 1 : 0
  backup_vault_name   = aws_backup_vault.backup_vault[0].name
  min_retention_days  = var.min_retention_days
  max_retention_days  = var.max_retention_days
  changeable_for_days = var.changeable_for_days
}

# IAM role creation removed - assuming iam_role_arn is always provided

resource "aws_backup_plan" "backup_plan" {
  for_each = var.enabled ? local.plans_map : {}
  name     = each.value.name

  dynamic "rule" {
    for_each = each.value.rules
    content {
      rule_name                = rule.value.rule_name
      target_vault_name        = var.vault_name
      schedule                 = try(rule.value.schedule, null)
      start_window             = try(rule.value.start_window, null)
      completion_window        = try(rule.value.completion_window, null)
      enable_continuous_backup = try(rule.value.enable_continuous_backup, null)

      dynamic "lifecycle" {
        for_each = try(rule.value.lifecycle, null) != null ? [rule.value.lifecycle] : []
        content {
          cold_storage_after = try(lifecycle.value.cold_storage_after, null)
          delete_after       = try(lifecycle.value.delete_after, null)
        }
      }

      dynamic "copy_action" {
        for_each = try(rule.value.copy_action, [])
        content {
        destination_vault_arn = copy_action.value.destination_vault_arn

      dynamic "lifecycle" {
        for_each = try(copy_action.value.lifecycle, null) != null ? [copy_action.value.lifecycle] : []
        content {
        cold_storage_after = try(lifecycle.value.cold_storage_after, null)
        delete_after       = try(lifecycle.value.delete_after, null)
      }
    }
  }
} 
   recovery_point_tags = try(rule.value.recovery_point_tags, {})
    }
  }
  tags = var.tags
}

resource "aws_backup_selection" "ab_selection" {
  for_each = var.enabled ? local.plan_selections_map : {}

  iam_role_arn = var.iam_role_arn
  name         = each.value.selection_key
  plan_id      = aws_backup_plan.backup_plan[each.value.plan_key].id

  resources     = try(each.value.selection.resources, [])
  not_resources = try(each.value.selection.not_resources, [])
  dynamic "selection_tag" {
    for_each = try(each.value.selection.selection_tags, [])
    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }

  dynamic "condition" {
    for_each = try(each.value.selection.conditions, {})
    content {
      dynamic "string_equals" {
        for_each = condition.value.type == "STRINGEQUALS" ? [condition.value] : []
        content {
          key   = condition.key
          value = string_equals.value.value
        }
      }

      dynamic "string_like" {
        for_each = condition.value.type == "STRINGLIKE" ? [condition.value] : []
        content {
          key   = condition.key
          value = string_like.value.value
        }
      }
    }
  }

  depends_on = [aws_backup_plan.backup_plan]
}
