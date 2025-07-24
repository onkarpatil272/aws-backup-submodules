
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

  backup_vault_name   = var.vault_name != null ? aws_backup_vault.backup_vault[0].name : "Default"
  sns_topic_arn       = each.value.sns_topic_arn
  backup_vault_events = each.value.backup_vault_events
}
resource "aws_cloudwatch_metric_alarm" "backup_alarm" {
  for_each = var.notifications

  alarm_name          = "Backup_${each.key}_Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = each.key == "backup_failure" ? "BackupJobsFailed" : "BackupMissedJobs"
  namespace           = "AWS/Backup"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm for ${each.key} events"
  alarm_actions       = [each.value.sns_topic_arn]
}