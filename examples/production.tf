# Production AWS Backup Example
# This example shows a comprehensive production backup setup

module "production_backup" {
  source = "../../"

  # Basic configuration
  enabled    = true
  vault_name = "production-backup-vault"
  aws_region = "us-east-1"

  # Vault configuration with tags
  vault_tags = {
    Environment = "production"
    Project     = "enterprise-backup"
    Owner       = "devops-team"
    CostCenter  = "backup-operations"
    Compliance  = "SOX"
  }

  # Vault lock for compliance
  locked               = true
  min_retention_days   = 30
  max_retention_days   = 2555  # 7 years
  changeable_for_days  = 7

  # Custom KMS encryption
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # IAM role
  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupServiceRole"

  # Multi-plan configuration for different backup strategies
  plans = [
    {
      name = "daily-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 12 * * ? *)"  # Daily at 12 PM UTC
          start_window = 60    # 1 hour
          completion_window = 120  # 2 hours
          lifecycle = {
            cold_storage_after = 30
            delete_after       = 90
          }
          recovery_point_tags = {
            BackupType = "daily"
            Environment = "production"
          }
        }
      ]
      selections = {
        "critical-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupServiceRole"
          resources = [
            "arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678",
            "arn:aws:rds:us-east-1:123456789012:db:production-database",
            "arn:aws:efs:us-east-1:123456789012:file-system/fs-12345678"
          ]
        }
      }
    },
    {
      name = "weekly-backup"
      rules = [
        {
          rule_name = "weekly"
          schedule  = "cron(0 12 ? * SUN *)"  # Weekly on Sunday
          lifecycle = {
            cold_storage_after = 90
            delete_after       = 365
          }
          recovery_point_tags = {
            BackupType = "weekly"
            Environment = "production"
          }
        }
      ]
      selections = {
        "all-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupServiceRole"
          selection_tags = [
            {
              type  = "STRINGEQUALS"
              key   = "Backup"
              value = "true"
            },
            {
              type  = "STRINGEQUALS"
              key   = "Environment"
              value = "production"
            }
          ]
        }
      }
    },
    {
      name = "monthly-backup"
      rules = [
        {
          rule_name = "monthly"
          schedule  = "cron(0 12 1 * ? *)"  # Monthly on 1st
          lifecycle = {
            cold_storage_after = 180
            delete_after       = 2555  # 7 years for compliance
          }
          recovery_point_tags = {
            BackupType = "monthly"
            Environment = "production"
            Compliance = "SOX"
          }
        }
      ]
      selections = {
        "compliance-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupServiceRole"
          resources = [
            "arn:aws:rds:us-east-1:123456789012:db:financial-database",
            "arn:aws:efs:us-east-1:123456789012:file-system/fs-financial-data"
          ]
        }
      }
    }
  ]

  # SNS notifications
  create_sns_topics = true
  notifications = {
    BACKUP_JOB = {
      enabled             = true
      backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
    }
    COPY_JOB = {
      enabled             = true
      backup_vault_events = ["COPY_JOB_COMPLETED", "COPY_JOB_FAILED"]
    }
    RESTORE_JOB = {
      enabled             = true
      backup_vault_events = ["RESTORE_JOB_COMPLETED", "RESTORE_JOB_FAILED"]
    }
    REPLICATION_JOB = {
      enabled             = true
      backup_vault_events = ["REPLICATION_JOB_COMPLETED", "REPLICATION_JOB_FAILED"]
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
      sns_topic_arn       = module.production_backup.sns_topic_arns["BACKUP_JOB"]
    }
    copy_failure = {
      metric_name         = "CopyJobsFailed"
      namespace           = "AWS/Backup"
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 1
      statistic           = "Sum"
      period              = 300
      alarm_description   = "Copy job failure alarm"
      sns_topic_arn       = module.production_backup.sns_topic_arns["COPY_JOB"]
    }
  }

  # Lifecycle defaults
  default_lifecycle_cold_storage_after_days = 30
  default_lifecycle_delete_after_days       = 120

  # Tags
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Component   = "backup"
    Compliance  = "SOX"
  }

  backup_plan_tags = {
    BackupType = "automated"
    Compliance = "SOX"
  }
}

# Outputs
output "production_vault_arn" {
  description = "Production backup vault ARN"
  value       = module.production_backup.vault_arn
}

output "production_plans" {
  description = "Production backup plans"
  value       = module.production_backup.plans
}

output "production_vault_lock_config" {
  description = "Production vault lock configuration"
  value       = module.production_backup.vault_lock_configuration
}

output "production_sns_topics" {
  description = "Production SNS topic ARNs"
  value       = module.production_backup.sns_topic_arns
} 