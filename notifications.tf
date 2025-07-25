
# IAM Policy to allow AWS Backup to publish to SNS topics
data "aws_iam_policy_document" "sns" {
  for_each = var.enabled && !var.notifications_disable_sns_policy ? var.notifications : {}

  statement {
    actions   = ["SNS:Publish"]
    effect    = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    resources = [each.value.sns_topic_arn]
    sid       = "BackupPublishEvents"
  }
}

# SNS Topic Policies
resource "aws_sns_topic_policy" "sns" {
  for_each = var.enabled && !var.notifications_disable_sns_policy ? var.notifications : {}

  arn    = each.value.sns_topic_arn
  policy = data.aws_iam_policy_document.sns[each.key].json
}

# Backup Vault Notifications
resource "aws_backup_vault_notifications" "this" {
  for_each = var.enabled ? var.notifications : {}

  backup_vault_name   = var.vault_name != null ? var.vault_name : "Default"
  sns_topic_arn       = each.value.sns_topic_arn
  backup_vault_events = each.value.backup_vault_events
}
resource "aws_cloudwatch_metric_alarm" "backup_failure_alarm" {
  for_each = var.enabled ? {
    for k, v in var.notifications : k => v if try(v.enabled, false)
  } : {}

  # Define inline backup metric mapping
  # Supports: BACKUP_JOB, COPY_JOB, RESTORE_JOB, REPLICATION_JOB
  # Fails for unsupported keys
  alarm_name          = "Backup-${each.key}-Failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name = lookup(
    {
      BACKUP_JOB      = "BackupJobsFailed"
      COPY_JOB        = "CopyJobsFailed"
      RESTORE_JOB     = "RestoreJobsFailed"
      REPLICATION_JOB = "ReplicationJobsFailed"
    },
    each.key,
    null
  )
  namespace         = "AWS/Backup"
  period            = 300
  statistic         = "Sum"
  threshold         = 1
  alarm_description = "Backup ${each.key} job failure alarm"

  alarm_actions = try(each.value.sns_topic_arn, null) != null ? [each.value.sns_topic_arn] : []

  lifecycle {
    precondition {
      condition     = lookup(
        {
          BACKUP_JOB      = "BackupJobsFailed"
          COPY_JOB        = "CopyJobsFailed"
          RESTORE_JOB     = "RestoreJobsFailed"
          REPLICATION_JOB = "ReplicationJobsFailed"
        },
        each.key,
        null
      ) != null
      error_message = "Unsupported notification key '${each.key}'. Please update the metric_name lookup map."
    }
  }
  tags= local.common_tags
}


# Support custom CloudWatch alarms from var.cloudwatch_alarms
resource "aws_cloudwatch_metric_alarm" "custom" {
  for_each = var.enabled ? var.cloudwatch_alarms : {}

  alarm_name          = each.value.alarm_name != null ? each.value.alarm_name : each.key
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.alarm_description
  alarm_actions       = [each.value.sns_topic_arn]
}