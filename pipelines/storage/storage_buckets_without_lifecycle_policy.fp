locals {
  storage_buckets_without_lifecycle_policy_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name,
      project,
      sp_connection_name as conn
    from
      gcp_storage_bucket
    where
      lifecycle_rules is null;
  EOQ

  storage_buckets_without_lifecycle_policy_enabled_actions = ["skip", "delete_storage_bucket", "delete_all_objects_and_storage_bucket"]
  storage_buckets_without_lifecycle_policy_default_action  = ["notify", "skip", "delete_storage_bucket", "delete_all_objects_and_storage_bucket"]
}

variable "storage_buckets_without_lifecycle_policy_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_buckets_without_lifecycle_policy_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_buckets_without_lifecycle_policy_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_storage_bucket", "delete_all_objects_and_storage_bucket"]

  tags = {
    folder = "Advanced/Storage"
  }
}

variable "storage_buckets_without_lifecycle_policy_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_storage_bucket", "delete_all_objects_and_storage_bucket"]
  enum        = ["skip", "delete_storage_bucket", "delete_all_objects_and_storage_bucket"]

  tags = {
    folder = "Advanced/Storage"
  }
}

trigger "query" "detect_and_correct_storage_buckets_without_lifecycle_policy" {
  title         = "Detect & correct Storage buckets without lifecycle policies"
  description   = "Identifies Storage buckets without lifecycle policies and executes the chosen action."
  documentation = file("./pipelines/storage/docs/detect_and_correct_storage_buckets_without_lifecycle_policy_trigger.md")
  tags          = merge(local.storage_common_tags, { class = "unused" })

  enabled  = var.storage_buckets_without_lifecycle_policy_trigger_enabled
  schedule = var.storage_buckets_without_lifecycle_policy_trigger_schedule
  database = var.database
  sql      = local.storage_buckets_without_lifecycle_policy_query

  capture "insert" {
    pipeline = pipeline.correct_storage_buckets_without_lifecycle_policy
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_storage_buckets_without_lifecycle_policy" {
  title         = "Detect & correct Storage buckets without lifecycle policies"
  description   = "Detects Storage buckets without lifecycle policies and runs your chosen action."
  documentation = file("./pipelines/storage/docs/detect_and_correct_storage_buckets_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused", recommended = "true" })

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
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
    default     = var.storage_buckets_without_lifecycle_policy_default_action
    enum        = local.storage_buckets_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_buckets_without_lifecycle_policy_enabled_actions
    enum        = local.storage_buckets_without_lifecycle_policy_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.storage_buckets_without_lifecycle_policy_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_storage_buckets_without_lifecycle_policy
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_storage_buckets_without_lifecycle_policy" {
  title         = "Correct Storage buckets without lifecycle policies"
  description   = "Executes corrective actions on Storage buckets without lifecycle policies."
  documentation = file("./pipelines/storage/docs/correct_storage_buckets_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      title   = string
      name    = string
      project = string
      conn    = string
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
    default     = var.storage_buckets_without_lifecycle_policy_default_action
    enum        = local.storage_buckets_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_buckets_without_lifecycle_policy_enabled_actions
    enum        = local.storage_buckets_without_lifecycle_policy_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Storage buckets without lifecycle policies."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_storage_bucket_without_lifecycle_policy
    args = {
      title              = each.value.title
      name               = each.value.name
      project            = each.value.project
      conn               = connection.gcp[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_storage_bucket_without_lifecycle_policy" {
  title         = "Correct one Storage bucket without lifecycle policies"
  description   = "Runs corrective action on a single Storage bucket without lifecycle policies."
  documentation = file("./pipelines/storage/docs/correct_one_storage_bucket_without_lifecycle_policy.md")
  tags          = merge(local.storage_common_tags, { class = "unused", folder = "Internal" })

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Storage bucket."
  }

  param "project" {
    type        = string
    description = local.description_project
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
    default     = var.storage_buckets_without_lifecycle_policy_default_action
    enum        = local.storage_buckets_without_lifecycle_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.storage_buckets_without_lifecycle_policy_enabled_actions
    enum        = local.storage_buckets_without_lifecycle_policy_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Storage bucket ${param.title} without lifecycle policies."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped Storage bucket ${param.title} without lifecycle policies."
          }
          success_msg = "Skipped Storage bucket ${param.title}."
          error_msg   = "Error skipping Storage bucket ${param.title}."
        },
        "delete_all_objects_and_storage_bucket" = {
          label        = "Delete All Objects and Storage Bucket"
          value        = "delete_all_objects_and_storage_bucket"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_all_objects_and_storage_bucket
          pipeline_args = {
            bucket_url = "gs://${param.name}"
            project_id = param.project
            conn       = param.conn
          }
          success_msg = "Deleted all objects and Storage bucket ${param.title}."
          error_msg   = "Error deleting all objects and Storage bucket ${param.title}."
        },
        "delete_storage_bucket" = {
          label        = "Delete Storage Bucket"
          value        = "delete_storage_bucket"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_storage_buckets
          pipeline_args = {
            bucket_urls = ["gs://${param.name}"]
            conn        = param.conn
            project_id  = param.project
          }
          success_msg = "Deleted Storage bucket ${param.title}."
          error_msg   = "Error deleting Storage bucket ${param.title}."
        }
      }
    }
  }
}
