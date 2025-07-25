
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
resource "aws_cloudwatch_metric_alarm" "backup_alarm" {
  for_each = var.enabled ? var.notifications : {}

  alarm_name          = "Backup_${each.key}_Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name = lookup(
    {
      backup_failure = "BackupJobsFailed"
      backup_missed  = "BackupMissedJobs"
    },
    each.key,
    "BackupJobsFailed"
  )
  namespace           = "AWS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm for ${each.key} events"
  alarm_actions       = [each.value.sns_topic_arn]
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