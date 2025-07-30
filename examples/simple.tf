# Simple AWS Backup Example
# This is the most basic configuration to get started

module "simple_backup" {
  source = "../../"

  # Basic configuration
  enabled    = true
  vault_name = "simple-backup-vault"
  
  # IAM role (required)
  iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"

  # Simple daily backup rule
  rules = [
    {
      rule_name = "daily"
      schedule  = "cron(0 12 * * ? *)"  # Daily at 12 PM UTC
    }
  ]

  # Backup selection - specify which resources to backup
  selections = {
    "default" = {
      iam_role_arn = "arn:aws:iam::123456789012:role/AWSBackupDefaultServiceRole"
      resources    = [
        "arn:aws:ec2:us-east-1:123456789012:volume/vol-12345678",
        "arn:aws:rds:us-east-1:123456789012:db:my-database"
      ]
    }
  }

  # Basic tags
  tags = {
    Environment = "dev"
    Project     = "backup-demo"
  }
}

# Output the vault ARN
output "backup_vault_arn" {
  description = "The ARN of the backup vault"
  value       = module.simple_backup.vault_arn
}

# Output the plan ID
output "backup_plan_id" {
  description = "The ID of the backup plan"
  value       = module.simple_backup.plan_id
} 