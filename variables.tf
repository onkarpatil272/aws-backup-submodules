variable "enabled" {
  description = "Enable or disable the AWS Backup module"
  type        = bool
  default     = true
}

variable "vaults" {
  description = "Map of backup vault configurations. Each vault can have its own settings."
  type = map(object({
    name                = string
    kms_key_arn         = optional(string)
    tags                = optional(map(string), {})
    locked              = optional(bool, false)
    min_retention_days  = optional(number)
    max_retention_days  = optional(number)
    changeable_for_days = optional(number)
  }))
  default = {}

  validation {
    condition = alltrue([
      for vault_name, vault_config in var.vaults : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,49}$", vault_config.name))
    ])
    error_message = "Each vault name must be 1-50 chars, start with a letter, and contain only alphanumeric, hyphen, underscore."
  }

  validation {
    condition = alltrue([
      for vault_name, vault_config in var.vaults :
      vault_config.kms_key_arn == null || can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:(key/[a-f0-9-]{36}|alias/[a-zA-Z0-9/_-]+)$", vault_config.kms_key_arn))
    ])
    error_message = "Each vault's kms_key_arn must be a valid AWS KMS key ARN or alias format."
  }

  validation {
    condition = alltrue([
      for vault_name, vault_config in var.vaults :
      !vault_config.locked || (vault_config.min_retention_days != null || vault_config.max_retention_days != null)
    ])
    error_message = "Vault lock requires at least one retention parameter (min_retention_days or max_retention_days) when locked is true."
  }

  validation {
    condition = alltrue([
      for vault_name, vault_config in var.vaults :
      !vault_config.locked ||
      (vault_config.min_retention_days == null || vault_config.max_retention_days == null ||
       vault_config.min_retention_days <= vault_config.max_retention_days)
    ])
    error_message = "min_retention_days cannot be greater than max_retention_days when vault lock is enabled."
  }
}

variable "iam_role_arn" {
  description = "IAM role ARN for AWS Backup service (required)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/[a-zA-Z0-9+=,.@_-]+$", var.iam_role_arn))
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

  validation {
    condition = alltrue([
      for rule in var.rules :
      try(rule.start_window, null) == null || try(rule.completion_window, null) == null ||
      (try(rule.start_window, 0) + try(rule.completion_window, 0)) >= 60
    ])
    error_message = "The interval between backup jobs (start_window + completion_window) must be at least 60 minutes for AWS Backup."
  }
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

  validation {
    condition = alltrue([
      for plan in var.plans : alltrue([
        for rule in plan.rules :
        try(rule.start_window, null) == null || try(rule.completion_window, null) == null ||
        (try(rule.start_window, 0) + try(rule.completion_window, 0)) >= 60
      ])
    ])
    error_message = "The interval between backup jobs (start_window + completion_window) must be at least 60 minutes for AWS Backup."
  }
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

variable "create_sns_topics" {
  description = "Whether to create SNS topics for backup notifications"
  type        = bool
  default     = false
}

variable "notifications" {
  description = "Map of backup vault notification configurations"
  type = map(object({
    enabled             = optional(bool)
    vault_name          = optional(string)
    sns_topic_arn       = optional(string)
    backup_vault_events = optional(list(string))
  }))
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