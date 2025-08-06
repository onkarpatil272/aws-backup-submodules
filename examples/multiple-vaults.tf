# Example: Multiple Vaults with Different Configurations
# This example shows how to create multiple backup vaults with different settings

module "backup_multiple_vaults" {
  source = "../../"

  enabled = true
  iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"

  # Define multiple vaults with different configurations
  vaults = {
    # Production vault with strict retention and encryption
    production = {
      name                = "prod-backup-vault"
      kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      tags = {
        Environment = "production"
        Criticality = "high"
        BackupType  = "critical"
      }
      locked              = true
      min_retention_days  = 90
      max_retention_days  = 2555  # 7 years
      changeable_for_days = 7
    }

    # Development vault with shorter retention
    development = {
      name                = "dev-backup-vault"
      kms_key_arn         = null  # Use AWS default encryption
      tags = {
        Environment = "development"
        Criticality = "low"
        BackupType  = "standard"
      }
      locked              = false
    }

    # Archive vault for long-term storage
    archive = {
      name                = "archive-backup-vault"
      kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
      tags = {
        Environment = "archive"
        Criticality = "medium"
        BackupType  = "long-term"
      }
      locked              = true
      min_retention_days  = 365   # 1 year minimum
      max_retention_days  = 3650  # 10 years maximum
      changeable_for_days = 30
    }
  }

  # Backup plans that can target different vaults
  plans = [
    {
      name = "daily-production-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 2 * * ? *)"  # 2 AM daily
        }
      ]
      selections = {
        "production-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"
          resources    = [
            "arn:aws:ec2:us-east-1:123456789012:volume/vol-prod-123",
            "arn:aws:rds:us-east-1:123456789012:db:prod-database"
          ]
        }
      }
    },
    {
      name = "weekly-development-backup"
      rules = [
        {
          rule_name = "weekly"
          schedule  = "cron(0 3 ? * SUN *)"  # 3 AM every Sunday
        }
      ]
      selections = {
        "development-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"
          resources    = [
            "arn:aws:ec2:us-east-1:123456789012:volume/vol-dev-456"
          ]
        }
      }
    },
    {
      name = "monthly-archive-backup"
      rules = [
        {
          rule_name = "monthly"
          schedule  = "cron(0 4 1 * ? *)"  # 4 AM on the 1st of every month
        }
      ]
      selections = {
        "archive-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/BackupRole"
          resources    = [
            "arn:aws:ec2:us-east-1:123456789012:volume/vol-archive-789"
          ]
        }
      }
    }
  ]

  # Notifications for different vaults
  notifications = {
    BACKUP_JOB = {
      enabled             = true
      sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:backup-notifications"
      backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
    }
  }

  # CloudWatch alarms
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
      sns_topic_arn       = "arn:aws:sns:us-east-1:123456789012:backup-alarms"
    }
  }

  tags = {
    Project = "MultiVaultBackup"
    Owner   = "DevOps"
  }
}

# Outputs to access vault information
output "vault_arns" {
  description = "ARNs of all created backup vaults"
  value       = module.backup_multiple_vaults.vaults
}

output "production_vault_arn" {
  description = "ARN of the production backup vault"
  value       = module.backup_multiple_vaults.vaults["production"].arn
}

output "vault_lock_configurations" {
  description = "Lock configurations for all vaults"
  value       = module.backup_multiple_vaults.vault_lock_configurations
} 