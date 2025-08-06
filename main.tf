data "aws_kms_key" "backup" {
  count  = var.enabled && length(var.vaults) > 0 ? 1 : 0
  key_id = "alias/aws/backup"
}

resource "aws_backup_vault" "backup_vault" {
  for_each    = local.should_create_vaults ? local.vaults_map : {}
  name        = each.value.name
  kms_key_arn = local.vault_kms_keys[each.key]
  tags        = each.value.tags
}

resource "aws_backup_vault_lock_configuration" "ab_vault_lock" {
  for_each = local.should_create_locks ? {
    for vault_key, vault_config in local.vaults_map :
    vault_key => vault_config if vault_config.locked
  } : {}

  backup_vault_name   = aws_backup_vault.backup_vault[each.key].name
  min_retention_days  = each.value.min_retention_days
  max_retention_days  = each.value.max_retention_days
  changeable_for_days = each.value.changeable_for_days

  depends_on = [aws_backup_vault.backup_vault]
}

resource "aws_backup_plan" "backup_plan" {
  for_each = var.enabled ? local.plans_map : {}
  name     = each.value.name

  dynamic "rule" {
    for_each = each.value.rules
    content {
      rule_name                = rule.value.rule_name
      target_vault_name        = length(local.vaults_map) > 0 ? values(local.vaults_map)[0].name : "Default"
      schedule                 = try(rule.value.schedule, null)
      start_window             = try(rule.value.start_window, null)
      completion_window        = try(rule.value.completion_window, null)
      enable_continuous_backup = try(rule.value.enable_continuous_backup, null)
      recovery_point_tags      = try(rule.value.recovery_point_tags, {})

      dynamic "lifecycle" {
        for_each = try(rule.value.lifecycle, null) != null ? [rule.value.lifecycle] : []
        content {
          cold_storage_after = try(lifecycle.value.cold_storage_after, null)
          delete_after       = try(lifecycle.value.delete_after, null)
        }
      }

      dynamic "copy_action" {
        for_each = local.enable_copy_action ? try(rule.value.copy_action, []) : []
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
    }
  }
  tags = local.backup_plan_tags
  depends_on = [aws_backup_vault.backup_vault]
}

resource "aws_backup_selection" "ab_selection" {
  for_each = var.enabled ? local.plan_selections_map : {}

  iam_role_arn = var.iam_role_arn
  name         = each.value.selection_key
  plan_id      = aws_backup_plan.backup_plan[each.value.plan_key].id

resources     = try(length(each.value.selection.resources), 0) > 0 ? each.value.selection.resources : null
not_resources = try(length(each.value.selection.not_resources), 0) > 0 ? each.value.selection.not_resources : null

  dynamic "selection_tag" {
    for_each = try(each.value.selection.selection_tags, null) != null ? each.value.selection.selection_tags : []
    content {
      type  = selection_tag.value.type
      key   = selection_tag.value.key
      value = selection_tag.value.value
    }
  }
  depends_on = [aws_backup_plan.backup_plan, aws_backup_vault.backup_vault]
}