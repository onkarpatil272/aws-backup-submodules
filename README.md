# AWS Backup Terraform Module

This Terraform module provisions AWS Backup resources, including backup vaults, plans, selections, notifications, and CloudWatch alarms. It is designed for flexible, production-grade backup management with tagging, vault lock, notification, and encryption support.

---

## Features

- **Backup Vaults**: Create and configure AWS Backup Vaults with optional KMS encryption and tagging.
- **Vault Lock**: Supports Vault Lock configuration for compliance and immutability.
- **Backup Plans**: Manage backup plans and rules (legacy single-plan and multi-plan modes).
- **Selections**: Flexible resource selection for backup plans.
- **Notifications**: Publishes backup events to SNS and CloudWatch.
- **CloudWatch Alarms**: Create alarms for backup job failures and other events.
- **Tagging**: Flexible tagging for all resources.
- **Region & Provider**: Easily configure AWS region and provider version.
- **Validation**: Comprehensive input validation and error handling.

---

## File Structure

- `main.tf`: Main resources for vaults, plans, selections, and lock configuration.
- `locals.tf`: Local values for plan composition, tags, and logic.
- `variables.tf`: All input variables with validation.
- `outputs.tf`: Useful outputs for vaults, plans, and selections.
- `notifications.tf`: SNS and CloudWatch notification resources.
- `provider.tf`: AWS provider configuration.
- `version.tf`: Terraform and provider version constraints.

---

## Requirements

- **Terraform**: >= 1.5.0
- **AWS Provider**: >= 5.0, < 6.0
- **IAM Role**: A valid IAM role ARN with AWS Backup permissions (required)

---

## Usage

```hcl
module "backup" {
  source = "github.com/onkarpatil272/aws-backup-submodules"

  enabled    = true
  vault_name = "my-backup-vault"
  vault_tags = { Environment = "prod" }
  locked     = true
  min_retention_days  = 30
  max_retention_days  = 365
  changeable_for_days = 7
  kms_key_arn         = null # or your KMS key ARN
  iam_role_arn        = "arn:aws:iam::123456789012:role/BackupRole" # REQUIRED

  plans = [
    {
      name = "daily-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 12 * * ? *)"
        }
      ]
      selections = {
        "default" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"
          resources    = ["arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678"]
        }
      }
    }
  ]

  notifications = {
    BACKUP_JOB = {
      enabled             = true
      sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:backup-topic"
      backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
    }
  }

  cloudwatch_alarms = {
    backup_failure = {
      metric_name         = "BackupJobsFailed"
      namespace           = "AWS/Backup"
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      statistic           = "Sum"
      period              = 300
      alarm_description   = "Backup job failure alarm"
      sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:backup-topic"
    }
  }

  tags = {
    Project = "Backup"
    Owner   = "DevOps"
  }
}
```

---

## Inputs

| Name                                   | Type      | Default     | Required | Description                                                        |
|---------------------------------------- |-----------|-------------|----------|--------------------------------------------------------------------|
| enabled                                | bool      | true        | No       | Enable or disable the AWS Backup module                            |
| vault_name                             | string    | null        | No       | Name of the backup vault. Required if enabling the module          |
| vault_tags                             | map(string)| {}         | No       | Tags to apply to the backup vault                                  |
| locked                                 | bool      | false       | No       | Whether to enable Vault Lock configuration                         |
| min_retention_days                     | number    | null        | No       | Minimum number of days to retain backups                           |
| max_retention_days                     | number    | null        | No       | Maximum number of days to retain backups                           |
| changeable_for_days                    | number    | null        | No       | Number of days the vault lock can be changed                       |
| kms_key_arn                            | string    | null        | No       | KMS key ARN to encrypt the backup vault (optional)                 |
| iam_role_arn                           | string    | -           | **Yes**  | IAM role ARN for AWS Backup service                                |
| rules                                  | list(object) | []        | No       | List of backup rules for legacy single-plan mode                   |
| plans                                  | list(object) | []        | No       | List of full backup plan definitions (name, rules, selections)     |
| selections                             | map(object) | {}        | No       | List of backup selections (legacy mode only)                       |
| default_lifecycle_cold_storage_after_days | number | 30         | No       | Default cold storage transition time (days)                        |
| default_lifecycle_delete_after_days     | number    | 120         | No       | Default deletion time after backup (days)                          |
| create_sns_topics                      | bool      | false       | No       | Whether to create SNS topics for backup notifications              |
| notifications                          | map(object) | {}        | No       | Map of backup vault notification configurations                    |
| notifications_disable_sns_policy       | bool      | false       | No       | Set true to skip creating SNS topic access policy                  |
| backup_plan_tags                       | map(string)| {}         | No       | Tags to apply to all backup plans                                  |
| aws_region                             | string    | "us-east-1" | No       | AWS region for backup resources                                    |
| cloudwatch_alarms                      | map(object) | {}        | No       | List of CloudWatch alarms for AWS Backup notifications             |
| tags                                   | map(string)| {}         | No       | Base tags applied to all AWS Backup resources                      |

See `variables.tf` for full details and validation rules.

---

## Outputs

| Name                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| vault_id                    | The name of the backup vault                     |
| vault_arn                   | The ARN of the backup vault                      |
| vault_recovery_points       | Number of recovery points in the backup vault    |
| plan_id                     | The id of the backup plan                        |
| plan_arn                    | The ARN of the backup plan                       |
| plan_version                | Version ID of the backup plan                    |
| plans                       | Map of backup plans created                      |
| plan_role                   | The service role used by the backup plan         |
| vault_kms_key_arn           | The KMS key used for vault encryption            |
| vault_lock_configuration    | Vault lock configuration for each backup vault   |
| backup_selection_ids        | Map of backup selection IDs                      |
| backup_vault_arn            | Alias output for backup vault ARN                |
| backup_plan_ids             | List of backup plan IDs                          |
| sns_topic_arns              | Map of SNS topic ARNs used for notifications     |
| plan_selections_map         | Map of plan selections                           |

See `outputs.tf` for all outputs.

---

## Provider

Configure your AWS provider in `provider.tf`:

```hcl
provider "aws" {
  region = var.aws_region
}
```

---

## Versioning

See `version.tf` for required Terraform and provider versions.

---

## Notes

- **IAM Role**: You must provide a valid IAM role ARN for AWS Backup (`iam_role_arn`).
- **Vault Lock**: When `locked = true`, you must provide at least one retention parameter (`min_retention_days` or `max_retention_days`).
- **Vault Names**: Must start with a letter and contain only alphanumeric characters, hyphens, and underscores.
- **Backup Intervals**: The interval between backup jobs (start_window + completion_window) must be at least 60 minutes (AWS requirement).
- **SNS Topics**: Set `create_sns_topics = true` to let the module create SNS topics if you do not provide ARNs.
- **Notifications**: Use the `notifications` map to configure backup vault events and SNS topics.
- **CloudWatch Alarms**: Use the `cloudwatch_alarms` map to define custom alarms for backup events.
- **Validation**: Extensive input validation is provided for all variables.
- **Copy Actions**: Properly detected in both legacy and multi-plan modes.

---

## Recent Fixes

- ✅ **Required IAM Role**: `iam_role_arn` is now required to prevent runtime errors
- ✅ **Vault Lock Validation**: Added validation for retention parameters when vault lock is enabled
- ✅ **Copy Action Detection**: Fixed to detect copy actions in both rules and plans
- ✅ **SNS Topic Policies**: Improved handling of null ARNs and dependencies
- ✅ **CloudWatch Alarms**: Fixed SNS topic reference to use local variable
- ✅ **Resource Dependencies**: Added proper dependencies between resources
- ✅ **Vault Name Validation**: Updated to prevent names starting with numbers
- ✅ **KMS Key Validation**: Enhanced to support key aliases

---

## License

MIT

---

If you need more examples or have questions, please refer to the comments in each `.tf` file or open an issue.
