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
    condition = (
      (!var.enabled) ||
      (
        var.vault_name != null &&
        can(regex("^[a-zA-Z0-9\\-_]{1,50}$", var.vault_name))
      )
    )
    error_message = "When the module is enabled you must provide a valid 'vault_name' (1-50 chars, alphanumeric, hyphen, underscore)."
  }
}
variable "vault_tags" {
  description = "Tags to apply to the backup vault"
  type        = map(string)
  default     = {}
}

variable "locked" {
  description = "Whether to enable Vault Lock configuration"
  type        = bool
  default     = false

   # Ensure Vault Lock is only enabled with both retention values supplied
  validation {
    condition = (
      !var.locked ||
      (
        var.min_retention_days != null &&
        var.max_retention_days != null &&
        var.max_retention_days >= var.min_retention_days
      )
    )
    error_message = "When 'locked' is true you must provide both 'min_retention_days' and 'max_retention_days', with max ≥ min."
  }
}

variable "min_retention_days" {
  description = "Minimum number of days to retain backups"
  type        = number
  default     = null

  validation {
    condition     = var.min_retention_days == null || (var.min_retention_days >= 1 && var.min_retention_days <= 36500)
    error_message = "min_retention_days must be between 1 and 36500 if specified."
  }
}

variable "max_retention_days" {
  description = "Maximum number of days to retain backups"
  type        = number
  default     = null

  validation {
     condition = (
       var.max_retention_days == null ||
       (
         var.max_retention_days >= (var.min_retention_days != null ? var.min_retention_days : 1) &&
         var.max_retention_days <= 36500
       )
     )
     error_message = "max_retention_days must be between 1-36500 and ≥ min_retention_days when both are specified."
    }
}
variable "changeable_for_days" {
  description = "Number of days the vault lock can be changed"
  type        = number
  default     = null

  validation {
    condition     = var.changeable_for_days == null || (var.changeable_for_days >= 3 && var.changeable_for_days <= 36500)
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
  description = "Backup vault notifications configuration."
  type = object({
    sns_topic_arn       = optional(string)
    backup_vault_events = optional(list(string))
   })
   default = {}
 }

variable "notifications_disable_sns_policy" {
  description = "Set true to skip creating SNS topic access policy"
  type        = bool
  default     = false
}

variable "backup_plan_tags" {
  description = "Tags to apply to all backup plans"
  type        = map(string)
  default     = {}
}
variable "aws_region" {
  description = "AWS region for backup resources"
  type        = string
  default     = "us-east-1"
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
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
variable "tags" {
  description = "Base tags applied to all AWS Backup resources"
  type        = map(string)
  default     = {}
}


