# AWS Backup Terraform Module

This module provisions AWS Backup resources using Terraform, including backup vaults, plans, selections, notifications, and CloudWatch alarms. It is designed for flexible, production-grade backup management with tagging, vault lock, and notification support.

## Features
- Creates and configures AWS Backup Vaults
- Supports Vault Lock configuration
- Manages backup plans and selections (legacy and multi-plan)
- Publishes notifications to SNS and CloudWatch
- Handles KMS encryption for vaults
- Flexible tagging for all resources

## Files
- `main.tf`: Main resources for vaults, plans, selections, and lock configuration
- `locals.tf`: Local values for plan composition, tags, and logic
- `variables.tf`: All input variables with validation
- `outputs.tf`: Useful outputs for vaults, plans, and selections
- `notifications.tf`: SNS and CloudWatch notification resources
- `provider.tf`: AWS provider configuration
- `version.tf`: Terraform and provider version constraints

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
  iam_role_arn        = "arn:aws:iam::123456789012:role/BackupRole"
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
      enabled         = true
      sns_topic_arn   = "arn:aws:sns:us-east-1:123456789012:backup-topic"
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

## Inputs
Below are the main input variables for this module. See `variables.tf` for full details.

| Name | Type | Default | Description |
|------|------|---------|-------------|
| enabled | bool | true | Enable or disable the AWS Backup module |
| vault_name | string | null | Name of the backup vault. Required if enabling the module |
| vault_tags | map(string) | {} | Tags to apply to the backup vault |
| locked | bool | false | Whether to enable Vault Lock configuration |
| min_retention_days | number | null | Minimum number of days to retain backups |
| max_retention_days | number | null | Maximum number of days to retain backups |
| changeable_for_days | number | null | Number of days the vault lock can be changed |
| kms_key_arn | string | null | KMS key ARN to encrypt the backup vault (optional) |
| iam_role_arn | string | null | IAM role ARN for AWS Backup service |
| rules | list(object) | [] | List of backup rules for legacy single-plan mode |
| plans | list(object) | [] | List of full backup plan definitions (name, rules, selections) |
| selections | map(object) | {} | List of backup selections (legacy mode only) |
| default_lifecycle_cold_storage_after_days | number | 30 | Default cold storage transition time (days) |
| default_lifecycle_delete_after_days | number | 120 | Default deletion time after backup (days) |
| notifications | object | {} | Backup vault notifications configuration |
| notifications_disable_sns_policy | bool | false | Set true to skip creating SNS topic access policy |
| backup_plan_tags | map(string) | {} | Tags to apply to all backup plans |
| aws_region | string | "us-east-1" | AWS region for backup resources |
| cloudwatch_alarms | map(object) | {} | List of CloudWatch alarms for AWS Backup notifications |
| tags | map(string) | {} | Base tags applied to all AWS Backup resources |

## Outputs
See `outputs.tf` for all outputs. Key outputs:
- `vault_id`, `vault_arn`, `vault_recovery_points`: Backup vault details
- `plan_id`, `plan_arn`, `plan_version`, `plans`: Backup plan details
- `plan_role`: IAM role used
- `vault_kms_key_arn`: KMS key used for vault
- `vault_lock_configuration`: Vault lock settings
- `backup_selection_ids`: Map of backup selection IDs

## Requirements
- Terraform >= 1.3.0
- AWS Provider >= 5.0

## Provider
Configure your AWS provider in `provider.tf`:
```hcl
provider "aws" {
  region = var.aws_region
}
```

## Versioning
See `version.tf` for required Terraform and provider versions.
