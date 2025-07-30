# AWS Backup Module Examples
# This file demonstrates various configurations for the AWS Backup Terraform module

# Example 1: Basic Backup Configuration
module "basic_backup" {
  source = "../../"

  enabled    = true
  vault_name = "basic-backup-vault"
  
  vault_tags = {
    Environment = "dev"
    Project     = "backup-demo"
    Owner       = "devops"
  }

  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  # Legacy single-plan mode
  rules = [
    {
      rule_name = "daily-backup"
      schedule  = "cron(0 12 * * ? *)"
      lifecycle = {
        cold_storage_after = 30
        delete_after       = 90
      }
    }
  ]

  selections = {
    "default" = {
      iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
      resources    = ["arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678"]
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Example 2: Advanced Multi-Plan Configuration
module "advanced_backup" {
  source = "../../"

  enabled    = true
  vault_name = "advanced-backup-vault"
  
  vault_tags = {
    Environment = "prod"
    Project     = "production-backup"
    Owner       = "devops"
  }

  locked               = true
  min_retention_days   = 30
  max_retention_days   = 365
  changeable_for_days  = 7
  kms_key_arn         = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  # Multi-plan configuration
  plans = [
    {
      name = "daily-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 12 * * ? *)"
          lifecycle = {
            cold_storage_after = 30
            delete_after       = 90
          }
        }
      ]
      selections = {
        "ec2-volumes" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
          resources    = ["arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678"]
        }
      }
    },
    {
      name = "weekly-backup"
      rules = [
        {
          rule_name = "weekly"
          schedule  = "cron(0 12 ? * SUN *)"
          lifecycle = {
            cold_storage_after = 90
            delete_after       = 365
          }
        }
      ]
      selections = {
        "rds-instances" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
          resources    = ["arn:aws:rds:us-east-1:123456789012:db:my-database"]
        }
      }
    }
  ]

  # SNS Notifications
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
  }

  # CloudWatch Alarms
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
      sns_topic_arn       = module.advanced_backup.sns_topic_arns["BACKUP_JOB"]
    }
  }

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    CostCenter  = "backup"
  }
}

# Example 3: Cross-Region Backup with Copy Actions
module "cross_region_backup" {
  source = "../../"

  enabled    = true
  vault_name = "cross-region-backup-vault"
  
  vault_tags = {
    Environment = "prod"
    Project     = "disaster-recovery"
    Owner       = "devops"
  }

  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  plans = [
    {
      name = "cross-region-backup"
      rules = [
        {
          rule_name = "daily-with-copy"
          schedule  = "cron(0 12 * * ? *)"
          lifecycle = {
            cold_storage_after = 30
            delete_after       = 90
          }
          copy_action = [
            {
              destination_vault_arn = "arn:aws:backup:us-west-2:123456789012:backup-vault/dr-backup-vault"
              lifecycle = {
                cold_storage_after = 90
                delete_after       = 365
              }
            }
          ]
        }
      ]
      selections = {
        "critical-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
          resources    = [
            "arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678",
            "arn:aws:rds:us-east-1:123456789012:db:critical-database"
          ]
        }
      }
    }
  ]

  notifications = {
    BACKUP_JOB = {
      enabled             = true
      backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
    }
    COPY_JOB = {
      enabled             = true
      backup_vault_events = ["COPY_JOB_COMPLETED", "COPY_JOB_FAILED"]
    }
  }

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Purpose     = "disaster-recovery"
  }
}

# Example 4: Tag-Based Resource Selection
module "tag_based_backup" {
  source = "../../"

  enabled    = true
  vault_name = "tag-based-backup-vault"
  
  vault_tags = {
    Environment = "prod"
    Project     = "tag-based-backup"
    Owner       = "devops"
  }

  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  plans = [
    {
      name = "tag-based-backup"
      rules = [
        {
          rule_name = "daily"
          schedule  = "cron(0 12 * * ? *)"
          lifecycle = {
            cold_storage_after = 30
            delete_after       = 90
          }
        }
      ]
      selections = {
        "tagged-resources" = {
          iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
          selection_tags = [
            {
              type  = "STRINGEQUALS"
              key   = "Backup"
              value = "true"
            },
            {
              type  = "STRINGEQUALS"
              key   = "Environment"
              value = "prod"
            }
          ]
        }
      }
    }
  ]

  notifications = {
    BACKUP_JOB = {
      enabled             = true
      backup_vault_events = ["BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED"]
    }
  }

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Backup      = "true"
  }
}

# Example 5: Minimal Configuration (Using Default Vault)
module "minimal_backup" {
  source = "../../"

  enabled = true
  # vault_name = null (uses default vault)
  
  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  rules = [
    {
      rule_name = "weekly"
      schedule  = "cron(0 12 ? * SUN *)"
    }
  ]

  selections = {
    "default" = {
      iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
      resources    = ["arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678"]
    }
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Outputs for examples
output "basic_backup_vault_arn" {
  description = "Basic backup vault ARN"
  value       = module.basic_backup.vault_arn
}

output "advanced_backup_plans" {
  description = "Advanced backup plans"
  value       = module.advanced_backup.plans
}

output "cross_region_backup_vault_id" {
  description = "Cross-region backup vault ID"
  value       = module.cross_region_backup.vault_id
}

output "tag_based_backup_selections" {
  description = "Tag-based backup selections"
  value       = module.tag_based_backup.backup_selection_ids
}

output "minimal_backup_plan_id" {
  description = "Minimal backup plan ID"
  value       = module.minimal_backup.plan_id
} 