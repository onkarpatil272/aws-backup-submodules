# AWS Backup Module Examples

This directory contains various examples demonstrating how to use the AWS Backup Terraform module for different scenarios and use cases.

## Examples Overview

### 1. `main.tf` - Comprehensive Examples
This file contains multiple examples showcasing different backup configurations:

- **Basic Backup**: Simple daily backup with minimal configuration
- **Advanced Multi-Plan**: Production-ready setup with multiple backup plans
- **Cross-Region Backup**: Disaster recovery setup with copy actions
- **Tag-Based Selection**: Using tags to automatically select resources
- **Minimal Configuration**: Using AWS default backup vault

### 2. `simple.tf` - Quick Start Example
A minimal example to get started quickly with basic daily backups.

### 3. `production.tf` - Enterprise Production Setup
A comprehensive production example with:
- Vault lock for compliance
- Multiple backup strategies (daily, weekly, monthly)
- SNS notifications and CloudWatch alarms
- Custom KMS encryption
- Tag-based resource selection
- SOX compliance considerations

### 4. `terraform.tfvars.example` - Variable Configuration
A template file showing how to configure the module using `terraform.tfvars`.

## How to Use These Examples

### Quick Start
1. Copy `simple.tf` to your Terraform configuration
2. Update the `iam_role_arn` with your actual IAM role
3. Modify the `resources` list to include your AWS resources
4. Run `terraform init` and `terraform plan`

### Using terraform.tfvars
1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Update the values according to your environment
3. Use the module in your main configuration:

```hcl
module "backup" {
  source = "path/to/aws-backup-submodules"
  # Variables will be loaded from terraform.tfvars
}
```

### Production Setup
1. Review `production.tf` for enterprise features
2. Customize the configuration for your compliance requirements
3. Update resource ARNs and IAM roles
4. Test in a non-production environment first

## Prerequisites

Before using these examples, ensure you have:

1. **IAM Role**: A valid IAM role with AWS Backup permissions
2. **AWS Resources**: Resources you want to backup (EC2 volumes, RDS instances, etc.)
3. **KMS Key** (optional): Custom KMS key for encryption
4. **SNS Topics** (optional): For notifications

## Common Resource ARN Formats

```hcl
# EC2 Volume
"arn:aws:ec2:region:account:volume/vol-12345678"

# RDS Database
"arn:aws:rds:region:account:db:database-name"

# EFS File System
"arn:aws:efs:region:account:file-system/fs-12345678"

# DynamoDB Table
"arn:aws:dynamodb:region:account:table/table-name"

# EBS Snapshot
"arn:aws:ec2:region:account:snapshot/snap-12345678"
```

## Cron Expression Examples

```hcl
# Daily at 12 PM UTC
schedule = "cron(0 12 * * ? *)"

# Weekly on Sunday at 12 PM UTC
schedule = "cron(0 12 ? * SUN *)"

# Monthly on 1st at 12 PM UTC
schedule = "cron(0 12 1 * ? *)"

# Every 6 hours
schedule = "cron(0 */6 * * ? *)"
```

## Best Practices

1. **Start Simple**: Begin with the simple example and add complexity as needed
2. **Test First**: Always test backup configurations in a non-production environment
3. **Monitor**: Set up notifications and alarms for backup failures
4. **Compliance**: Use vault lock for compliance requirements
5. **Tagging**: Use consistent tagging for resource selection
6. **Lifecycle**: Configure appropriate lifecycle policies for cost optimization

## Troubleshooting

### Common Issues

1. **IAM Role Permissions**: Ensure your IAM role has the necessary AWS Backup permissions
2. **Resource ARNs**: Verify that resource ARNs are correct and accessible
3. **Schedule Format**: Use valid cron expressions for backup schedules
4. **Vault Lock**: Be careful with vault lock as it cannot be easily changed

### Validation Errors

The module includes extensive validation for:
- Vault name format
- Retention period ranges
- KMS key ARN format
- IAM role ARN format
- AWS region format

Check the error messages for specific validation failures.

## Support

For issues or questions:
1. Check the main module README.md
2. Review the comments in the .tf files
3. Open an issue in the repository 