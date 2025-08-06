# AWS Backup Terraform Module

This Terraform module provisions AWS Backup resources, including multiple backup vaults, plans, selections, notifications, and CloudWatch alarms. It is designed for flexible, production-grade backup management with tagging, vault lock, notification, and encryption support.

**Multiple Vaults Support** - The module supports creating multiple backup vaults with individual configurations per vault.

---

## Features

- **Multiple Backup Vaults**: Create and configure multiple AWS Backup Vaults with individual KMS encryption, tags, and lock settings.
- **Multiple Vault Locks**: Each vault can have its own lock configuration with individual retention policies.
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

### Multiple Vaults

```hcl
module "backup" {
  source = "github.com/onkarpatil272/aws-backup-submodules"

  enabled = true
  iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"

  # Define multiple vaults with different configurations
  vaults = {
    production = {
      name                = "prod-backup-vault"
      kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      tags = {
        Environment = "production"
        Criticality = "high"
      }
      locked              = true
      min_retention_days  = 90
      max_retention_days  = 2555
      changeable_for_days = 7
    }

    development = {
      name                = "dev-backup-vault"
      kms_key_arn         = null
      tags = {
        Environment = "development"
        Criticality = "low"
      }
      locked              = false
    }

    archive = {
      name                = "archive-backup-vault"
      kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
      tags = {
        Environment = "archive"
        BackupType  = "long-term"
      }
      locked              = true
      min_retention_days  = 365
      max_retention_days  = 3650
      changeable_for_days = 30
    }
  }

  plans = [
    {
      name = "daily-production-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 2 * * ? *)"
        }
      ]
      selections = {
        "production-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"
          resources    = ["arn:aws:ec2:us-east-1:123456789012:volume/vol-prod-123"]
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
| vaults                                 | map(object)| {}         | No       | Map of backup vault configurations (multiple vaults)               |
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

### Vault Configuration Object

Each vault in the `vaults` map can have the following configuration:

```hcl
vaults = {
  vault_key = {
    name                = string                    # Required: Vault name
    kms_key_arn         = optional(string)          # Optional: KMS key ARN for encryption
    tags                = optional(map(string), {}) # Optional: Vault-specific tags
    locked              = optional(bool, false)     # Optional: Enable vault lock
    min_retention_days  = optional(number)          # Optional: Minimum retention days
    max_retention_days  = optional(number)          # Optional: Maximum retention days
    changeable_for_days = optional(number)          # Optional: Days vault lock can be changed
  }
}
```

See `variables.tf` for full details and validation rules.

---

## Outputs

| Name                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| vaults                      | Map of all backup vaults created                 |
| plans                       | Map of backup plans created                      |
| plan_role                   | The service role used by the backup plan         |
| vault_lock_configurations   | Map of vault lock configurations for all vaults |
| backup_selection_ids        | Map of backup selection IDs                      |
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
- **Multiple Vaults**: Use the `vaults` variable to create multiple vaults with different configurations.
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

- ✅ **Multiple Vaults Support**: Clean implementation supporting multiple backup vaults with individual configurations
- ✅ **Multiple Vault Locks**: Each vault can have its own lock configuration with individual retention settings
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
