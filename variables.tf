variable "enabled" {
  description = "Enable or disable the AWS Backup module"
  type        = bool
  default     = true
}

variable "vault_name" {
  description = "Name of the backup vault. Required if enabling the module."
  type        = string
  default     = null

  validation {
    condition     = var.vault_name == null || can(regex("^[a-zA-Z0-9\\-_]{1,50}$", var.vault_name))
    error_message = "The 'vault_name' must be 1-50 characters long and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "cross_region_vault_arn" {
  description = "ARN of backup vault in the destination region for cross-region copy"
  type        = string
  default     = null
}


variable "locked" {
  description = "Whether to enable Vault Lock configuration"
  type        = bool
  default     = false
}

variable "min_retention_days" {
  description = "Minimum retention period in days for Vault Lock"
  type        = number
  default     = null

  validation {
    condition     = var.min_retention_days == null || can(var.min_retention_days >= 1 && var.min_retention_days <= 36500)
    error_message = "The 'min_retention_days' must be between 1 and 36500 days (100 years) when specified."
  }
}

variable "max_retention_days" {
  description = "Maximum retention period in days for Vault Lock"
  type        = number
  default     = null

  validation {
    condition     = var.max_retention_days == null || can(var.max_retention_days >= 1 && var.max_retention_days <= 36500)
    error_message = "The 'max_retention_days' must be between 1 and 36500 days (100 years) when specified."
  }
}

variable "changeable_for_days" {
  description = "Number of days the vault lock can be changed"
  type        = number
  default     = null

  validation {
    condition     = var.changeable_for_days == null || can(var.changeable_for_days >= 3 && var.changeable_for_days <= 36500)
    error_message = "The 'changeable_for_days' must be between 3 and 36500 days when specified."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt the backup vault (optional)"
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]{36}$", var.kms_key_arn))
    error_message = "The 'kms_key_arn' must be a valid AWS KMS key ARN format."
  }
}

variable "iam_role_arn" {
  description = "IAM role ARN for AWS Backup service (optional - will create one if not provided)"
  type        = string
  default     = null

  validation {
    condition     = var.iam_role_arn == null || can(regex("^arn:aws:iam::[0-9]{12}:role/[a-zA-Z0-9+=,.@_-]+$", var.iam_role_arn))
    error_message = "The 'iam_role_arn' must be a valid AWS IAM role ARN format."
  }
}

variable "rules" {
  description = "List of backup rules for legacy single-plan mode"
  type = list(object({
    rule_name         = string
    schedule          = optional(string)
    start_window      = optional(number)
    completion_window = optional(number)
    lifecycle = optional(object({
      cold_storage_after = optional(number)
      delete_after       = optional(number)
    }))
    recovery_point_tags      = optional(map(string))
    enable_continuous_backup = optional(bool)
    copy_action = optional(list(object({
      destination_vault_arn = string
      lifecycle = optional(object({
        cold_storage_after = optional(number)
        delete_after       = optional(number)
      }))
    })))
  }))
  default = []
}

variable "plans" {
  description = "List of full backup plan definitions (name, rules, selections)"
  type = list(object({
    name = optional(string)
    rules = list(object({
      rule_name         = string
      schedule          = optional(string)
      start_window      = optional(number)
      completion_window = optional(number)
      lifecycle = optional(object({
        cold_storage_after = optional(number)
        delete_after       = optional(number)
      }))
      recovery_point_tags      = optional(map(string))
      enable_continuous_backup = optional(bool)
      copy_action = optional(list(object({
        destination_vault_arn = string
        lifecycle = optional(object({
          cold_storage_after = optional(number)
          delete_after       = optional(number)
        }))
      })))
    }))
    selections = optional(map(object({
      iam_role_arn  = string
      resources     = optional(list(string))
      not_resources = optional(list(string))
      selection_tags = optional(list(object({
        type  = string
        key   = string
        value = string
      })))
      conditions = optional(map(object({
        type  = string
        value = string
      })))
    })))
  }))
  default = []
}

variable "selections" {
  description = "List of backup selections (legacy mode only)"
  type = map(object({
    iam_role_arn  = string
    resources     = optional(list(string))
    not_resources = optional(list(string))
    selection_tags = optional(list(object({
      type  = string
      key   = string
      value = string
    })))
    conditions = optional(map(object({
      type  = string
      value = string
    })))
  }))
  default = {}
}

variable "selection_resources" {
  description = "Legacy list of resource ARNs to include in backup (if not using selections)"
  type        = list(string)
  default     = []
}

variable "default_lifecycle_cold_storage_after_days" {
  description = "Default cold storage transition time (days)"
  type        = number
  default     = 30

  validation {
    condition     = var.default_lifecycle_cold_storage_after_days >= 30 && var.default_lifecycle_cold_storage_after_days <= 36500
    error_message = "The 'default_lifecycle_cold_storage_after_days' must be between 30 and 36500 days (AWS requirement)."
  }
}

variable "default_lifecycle_delete_after_days" {
  description = "Default deletion time after backup (days)"
  type        = number
  default     = 120

  validation {
    condition     = var.default_lifecycle_delete_after_days >= 90 && var.default_lifecycle_delete_after_days <= 36500
    error_message = "The 'default_lifecycle_delete_after_days' must be between 90 and 36500 days (AWS requirement)."
  }
}

variable "notifications" {
  description = "Backup vault notifications configuration (SNS topic ARN, events)"
  type        = map(any)
  default     = {}

  validation {
    condition = (
      length(var.notifications) == 0 ||
      (
        contains(keys(var.notifications), "sns_topic_arn") &&
        contains(keys(var.notifications), "backup_vault_events")
      )
    )

    error_message = "If 'notifications' is provided, it must include both 'sns_topic_arn' and 'backup_vault_events'."
  }
}

variable "notifications_disable_sns_policy" {
  description = "Set true to skip creating SNS topic access policy"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
variable "aws_region" {
  description = "AWS region for backup resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == null || can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "The 'aws_region' must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "cloudwatch_alarms" {
  description = "List of CloudWatch alarms for AWS Backup notifications"
  type = map(object({
    metric_name         = string
    namespace           = string
    threshold           = number
    comparison_operator = string
    evaluation_periods  = number
    statistic           = string
    period              = number
    alarm_description   = string
    sns_topic_arn       = string
  }))
  default = {}
}

