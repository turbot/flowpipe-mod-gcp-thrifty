locals {
  redis_instances_exceeding_max_age_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name,
      sp_connection_name as conn,
      location,
      project
    from
      gcp_redis_instance
    where
      date_part('day', now()-create_time) > ${var.redis_instances_exceeding_max_age_days};
  EOQ

  redis_instances_exceeding_max_age_enabled_actions = ["skip", "delete_redis_instance"]
  redis_instances_exceeding_max_age_default_action  = ["notify", "skip", "delete_redis_instance"]
}

variable "redis_instances_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Redis"
  }
}

variable "redis_instances_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Redis"
  }
}

variable "redis_instances_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_redis_instance"]

  tags = {
    folder = "Advanced/Redis"
  }
}

variable "redis_instances_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_redis_instance"]
  enum        = ["skip", "delete_redis_instance"]

  tags = {
    folder = "Advanced/Redis"
  }
}

variable "redis_instances_exceeding_max_age_days" {
  type        = number
  description = "The maximum number of days Redis instances can be retained."
  default     = 15
  tags = {
    folder = "Advanced/Redis"
  }
}

trigger "query" "detect_and_correct_redis_instances_exceeding_max_age" {
  title         = "Detect & correct Redis instances exceeding max age"
  description   = "Detects Redis instances that have been running for too long and runs your chosen action."
  documentation = file("./pipelines/redis/docs/detect_and_correct_redis_instances_exceeding_max_age_trigger.md")
  tags          = merge(local.redis_common_tags, { class = "unused" })

  enabled  = var.redis_instances_exceeding_max_age_trigger_enabled
  schedule = var.redis_instances_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.redis_instances_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_redis_instances_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_redis_instances_exceeding_max_age" {
  title         = "Detect & correct Redis instances exceeding max age"
  description   = "Detects Redis instances that have been running for too long and runs your chosen action."
  documentation = file("./pipelines/redis/docs/detect_and_correct_redis_instances_exceeding_max_age.md")
  tags          = merge(local.redis_common_tags, { class = "unused", recommended = "true" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.redis_instances_exceeding_max_age_default_action
    enum        = local.redis_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.redis_instances_exceeding_max_age_enabled_actions
    enum        = local.redis_instances_exceeding_max_age_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.redis_instances_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_redis_instances_exceeding_max_age
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

pipeline "correct_redis_instances_exceeding_max_age" {
  title         = "Correct Redis instances exceeding max age"
  description   = "Runs corrective action on a collection of long-running Redis instances."
  documentation = file("./pipelines/redis/docs/correct_redis_instances_exceeding_max_age.md")
  tags          = merge(local.redis_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      title    = string
      name     = string
      location = string
      project  = string
      conn     = string
    }))
    description = local.description_items
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.redis_instances_exceeding_max_age_default_action
    enum        = local.redis_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.redis_instances_exceeding_max_age_enabled_actions
    enum        = local.redis_instances_exceeding_max_age_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Redis instances exceeding max age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_redis_instance_exceeding_max_age
    args = {
      name               = each.value.name
      project            = each.value.project
      conn               = connection.gcp[each.value.conn]
      title              = each.value.title
      location           = each.value.location
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_redis_instance_exceeding_max_age" {
  title         = "Correct one Redis instance exceeding max age"
  description   = "Runs corrective action on a Redis instance that has been running for too long."
  documentation = file("./pipelines/redis/docs/correct_one_redis_instance_exceeding_max_age.md")
  tags          = merge(local.redis_common_tags, { class = "unused", folder = "Internal" })

  param "name" {
    type        = string
    description = "The name of the Redis instance."
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

  param "location" {
    type        = string
    description = local.description_location
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.redis_instances_exceeding_max_age_default_action
    enum        = local.redis_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.redis_instances_exceeding_max_age_enabled_actions
    enum        = local.redis_instances_exceeding_max_age_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Redis instance ${param.title} exceeding max age."
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
            text     = "Skipped Redis instance ${param.title} exceeding max age."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_redis_instance" = {
          label        = "Delete Redis Instance"
          value        = "delete_redis_instance"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_redis_instance
          pipeline_args = {
            instance_name = param.name
            project_id    = param.project
            conn          = param.conn
            region        = param.location
          }
          success_msg = "Deleted Redis instance ${param.title}."
          error_msg   = "Error deleting Redis instance ${param.title}."
        }
      }
    }
  }
}
