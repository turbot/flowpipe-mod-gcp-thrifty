locals {
  sql_db_instances_long_running_query = <<-EOQ
  select
    concat(name, ' [', location, '/', project, ']') as title,
    name,
    _ctx ->> 'connection_name' as cred,
    project
  from
    gcp_sql_database_instance
  where
    date_part('day', now()-create_time) > ${var.sql_db_instances_exceeding_max_age_days};
  EOQ
}

trigger "query" "detect_and_correct_sql_db_instances_long_running" {
  title         = "Detect & correct long-running SQL database instances"
  description   = "Detects SQL database instances that have been running for too long and runs your chosen action."
  documentation = file("./sql/docs/detect_and_correct_sql_db_instances_long_running_trigger.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  enabled  = var.sql_db_instances_long_running_trigger_enabled
  schedule = var.sql_db_instances_long_running_trigger_schedule
  database = var.database
  sql      = local.sql_db_instances_long_running_query

  capture "insert" {
    pipeline = pipeline.correct_sql_db_instances_long_running
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_db_instances_long_running" {
  title         = "Detect & correct long-running SQL database instances"
  description   = "Detects SQL database instances that have been running for too long and runs your chosen action."
  documentation = file("./sql/docs/detect_and_correct_sql_db_instances_long_running.md")
  tags          = merge(local.sql_common_tags, { class = "unused", type = "featured" })

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.sql_db_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_long_running_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_db_instances_long_running_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_db_instances_long_running
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

pipeline "correct_sql_db_instances_long_running" {
  title         = "Correct long-running SQL database instances"
  description   = "Runs corrective action on a collection of long-running SQL database instances."
  documentation = file("./sql/docs/correct_sql_db_instances_long_running.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title    = string
      name     = string
      project  = string
      cred     = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.sql_db_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_long_running_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} long-running SQL database instances."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_db_instance_long_running
    args = {
      name               = each.value.name
      project            = each.value.project
      cred               = each.value.cred
      title              = each.value.title
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_sql_db_instance_long_running" {
  title         = "Correct one long-running SQL database instance"
  description   = "Runs corrective action on an SQL database instance that has been running for too long."
  documentation = file("./sql/docs/correct_one_sql_db_instance_long_running.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "name" {
    type        = string
    description = "The name of the SQL database instance."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.sql_db_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_long_running_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL database instance ${param.title} running for too long."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped SQL database instance ${param.title} running for too long."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_sql_db_instance" = {
          label        = "Delete SQL Database Instance"
          value        = "delete_sql_db_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_sql_instance
          pipeline_args = {
            cred          = param.cred
            instance_name = param.name
            project_id    = param.project
          }
          success_msg = "Deleted SQL database instance ${param.title}."
          error_msg   = "Error deleting SQL database instance ${param.title}."
        }
      }
    }
  }
}

variable "sql_db_instances_long_running_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "sql_db_instances_long_running_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "sql_db_instances_long_running_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "sql_db_instances_long_running_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_sql_db_instance"]
}

variable "sql_db_instances_exceeding_max_age_days" {
  type        = number
  description = "The maximum number of days SQL database instances can be retained."
  default     = 15
}
