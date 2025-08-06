
# IAM Policy to allow AWS Backup to publish to SNS topics
data "aws_iam_policy_document" "sns" {
  for_each = var.enabled && !var.notifications_disable_sns_policy ? {
    for k, v in var.notifications :
    k => v if try(v.enabled, false) && try(v.sns_topic_arn, null) != null
  } : {}

  statement {
    actions = ["SNS:Publish"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    resources = [each.value.sns_topic_arn]
    sid       = "BackupPublishEvents"
  }
}

resource "aws_sns_topic" "this" {
  for_each = var.create_sns_topics ? {
    for k, v in var.notifications :
    k => v if try(v.enabled, false) && try(v.sns_topic_arn, null) == null
  } : {}

  name = "backup-topic-${each.key}"
}

# SNS Topic Policies
resource "aws_sns_topic_policy" "sns" {
  for_each = var.enabled && !var.notifications_disable_sns_policy ? {
    for k, v in var.notifications : k => v if try(v.enabled, false) && try(local.sns_topic_arns[k], null) != null
  } : {}

  arn = local.sns_topic_arns[each.key]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowBackupServiceToPublish"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = local.sns_topic_arns[each.key]
      }
    ]
  })
}

# Backup Vault Notifications
resource "aws_backup_vault_notifications" "this" {
  for_each = var.enabled ? {
    for k, v in var.notifications : k => v
    if try(v.enabled, false) &&
    try(v.sns_topic_arn, null) != null &&
    try(v.backup_vault_events, []) != []
  } : {}

  backup_vault_name = coalesce(
    try(each.value.vault_name, null),
    length(local.vaults_map) > 0 ? values(local.vaults_map)[0].name : "Default"
  )
  sns_topic_arn       = each.value.sns_topic_arn
  backup_vault_events = each.value.backup_vault_events
  depends_on = [aws_sns_topic_policy.sns, aws_sns_topic.this]
}

resource "aws_cloudwatch_metric_alarm" "backup_failure_alarm" {
  for_each = var.enabled ? {
    for k, v in var.notifications :
    k => v if try(v.enabled, false) && contains([
      "BACKUP_JOB", "COPY_JOB", "RESTORE_JOB", "REPLICATION_JOB"
    ], k)
  } : {}

  alarm_name          = "Backup-${each.key}-Failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = lookup(local.backup_alarm_metric_map, each.key, null)
  namespace           = "AWS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Backup ${each.key} job failure alarm"

  alarm_actions = try(local.sns_topic_arns[each.key], null) != null ? [local.sns_topic_arns[each.key]] : []

  dimensions = {
    BackupVaultName = coalesce(
      try(each.value.vault_name, null),
      length(local.vaults_map) > 0 ? values(local.vaults_map)[0].name : "Default"
    )
  }

  lifecycle {
    precondition {
      condition     = lookup(local.backup_alarm_metric_map, each.key, null) != null
      error_message = "Unsupported notification key '${each.key}'. Please update the metric_name map."
    }
  }

  tags = local.common_tags
}
