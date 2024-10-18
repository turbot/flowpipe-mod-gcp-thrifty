locals {
  logging_buckets_with_higher_retention_period_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name as bucket_name,
      location,
      project,
      sp_connection_name as conn
    from
      gcp_logging_bucket
    where
      name != '_Required'
      and retention_days > ${var.logging_bucket_max_retention_days};
  EOQ

  logging_buckets_with_high_retention_default_action  = ["notify", "skip", "update_retention"]
  logging_buckets_with_high_retention_enabled_actions = ["skip", "update_retention"]
}

variable "logging_buckets_with_high_retention_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Logging"
  }
}

variable "logging_buckets_with_high_retention_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Logging"
  }
}

variable "logging_buckets_with_high_retention_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "update_retention"]

  tags = {
    folder = "Advanced/Logging"
  }
}

variable "logging_buckets_with_high_retention_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_retention"]
  enum        = ["skip", "update_retention"]

  tags = {
    folder = "Advanced/Logging"
  }
}

variable "logging_bucket_max_retention_days" {
  type        = number
  description = "The maximum number of days a Logging Bucket retention period can be."
  default     = 20
  tags = {
    folder = "Advanced/Logging"
  }
}

variable "retention_days" {
  type        = string
  description = "The retention period in days to set for the Logging Buckets. Optional."
  default     = "10"
  tags = {
    folder = "Advanced/Logging"
  }
}

trigger "query" "detect_and_correct_logging_buckets_with_high_retention" {
  title         = "Detect & correct Logging Buckets with high retention period"
  description   = "Detects Logging Buckets with retention periods exceeding the specified maximum and runs your chosen action."
  documentation = file("./pipelines/logging/docs/detect_and_correct_logging_buckets_with_high_retention_trigger.md")
  tags          = merge(local.logging_common_tags, { class = "unused" })

  enabled  = var.logging_buckets_with_high_retention_trigger_enabled
  schedule = var.logging_buckets_with_high_retention_trigger_schedule
  database = var.database
  sql      = local.logging_buckets_with_higher_retention_period_query

  capture "insert" {
    pipeline = pipeline.correct_logging_buckets_with_high_retention
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_logging_buckets_with_high_retention" {
  title         = "Detect & correct Logging Buckets with high retention period"
  description   = "Detects Logging Buckets with retention periods exceeding the specified maximum and runs your chosen action."
  documentation = file("./pipelines/logging/docs/detect_and_correct_logging_buckets_with_high_retention.md")
  tags          = merge(local.logging_common_tags, { class = "unused", recommended = "true" })

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "retention_days" {
    type        = string
    description = "The retention period in days to set for the Logging Buckets. Optional."
    default     = var.retention_days
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.logging_buckets_with_high_retention_default_action
    enum        = local.logging_buckets_with_high_retention_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.logging_buckets_with_high_retention_enabled_actions
    enum        = local.logging_buckets_with_high_retention_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.logging_buckets_with_higher_retention_period_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_logging_buckets_with_high_retention
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      retention_days     = param.retention_days
    }
  }
}

pipeline "correct_logging_buckets_with_high_retention" {
  title         = "Correct Logging Buckets with high retention period"
  description   = "Runs corrective action on a collection of Logging Buckets with high retention periods."
  documentation = file("./pipelines/logging/docs/correct_logging_buckets_with_high_retention.md")
  tags          = merge(local.logging_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      bucket_name = string
      location    = string
      project     = string
      conn        = string
      title       = string
    }))
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.logging_buckets_with_high_retention_default_action
    enum        = local.logging_buckets_with_high_retention_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.logging_buckets_with_high_retention_enabled_actions
    enum        = local.logging_buckets_with_high_retention_enabled_actions
  }

  param "retention_days" {
    type        = string
    description = "The new retention period in days for the Logging Bucket. Optional."
    default     = var.retention_days
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Logging Buckets with high retention period."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.bucket_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_logging_bucket_with_high_retention
    args = {
      bucket_name        = each.value.bucket_name
      location           = each.value.location
      project            = each.value.project
      conn               = connection.gcp[each.value.conn]
      title              = each.value.title
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      retention_days     = param.retention_days
    }
  }
}

pipeline "correct_one_logging_bucket_with_high_retention" {
  title         = "Correct one Logging Bucket with high retention period"
  description   = "Runs corrective action on a Logging Bucket with high retention period."
  documentation = file("./pipelines/logging/docs/correct_one_logging_bucket_with_high_retention.md")
  tags          = merge(local.logging_common_tags, { class = "unused", folder = "Internal" })

  param "bucket_name" {
    type        = string
    description = "The name of the Logging Bucket."
  }

  param "location" {
    type        = string
    description = local.description_location
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.logging_buckets_with_high_retention_default_action
    enum        = local.logging_buckets_with_high_retention_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.logging_buckets_with_high_retention_enabled_actions
    enum        = local.logging_buckets_with_high_retention_enabled_actions
  }

  param "retention_days" {
    type        = string
    description = "The new retention period in days for the Logging Bucket. Optional."
    default     = var.retention_days
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Logging Bucket ${param.title} with high retention period."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        skip = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped Logging Bucket ${param.title} with high retention period."
          }
          success_msg = "Skipped Logging Bucket ${param.title}."
          error_msg   = "Error skipping Logging Bucket ${param.title}."
        }
        update_retention = {
          label        = "Update Retention Period"
          value        = "update_retention"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.update_logging_bucket
          pipeline_args = {
            bucket_id      = param.bucket_name
            location       = param.location
            project_id     = param.project
            conn           = param.conn
            retention_days = param.retention_days
          }
          success_msg = "Updated retention period for Logging Bucket ${param.title}."
          error_msg   = "Error updating retention period for Logging Bucket ${param.title}."
        }
      }
    }
  }
}
