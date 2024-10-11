locals {
  sql_db_instances_low_cpu_utilization_query = <<-EOQ
    with sql_db_instance_usage as (
      select
        instance_id,
        round(cast(sum(maximum) / count(maximum) as numeric), 1) as avg_max,
        count(maximum) as days
      from
        gcp_sql_database_instance_metric_cpu_utilization_daily
      where
        date_part('day', now() - timestamp) <= 30
      group by
        instance_id
    )
    select
      concat(i.name, ' [', i.location, '/', i.project, ']') as title,
      i.name as instance_name,
      i.project as project,
      i.sp_connection_name as conn
    from
      gcp_sql_database_instance as i
      left join sql_db_instance_usage as u on i.project || ':' || i.name = u.instance_id
    where
      avg_max <= ${var.alarm_threshold};
  EOQ
}

trigger "query" "detect_and_correct_sql_db_instances_with_low_cpu_utilization" {
  title         = "Detect & correct SQL DB instances with low cpu utilization"
  description   = "Detects SQL DB instances with low cpu utilization and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_db_instances_with_low_cpu_utilization_trigger.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  enabled  = var.sql_db_instances_with_low_cpu_utilization_trigger_enabled
  schedule = var.sql_db_instances_with_low_cpu_utilization_trigger_schedule
  database = var.database
  sql      = local.sql_db_instances_low_cpu_utilization_query

  capture "insert" {
    pipeline = pipeline.correct_sql_db_instances_with_low_cpu_utilization
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_db_instances_with_low_cpu_utilization" {
  title         = "Detect & correct SQL DB instances with low cpu utilization"
  description   = "Detects SQL DB instances with low cpu utilization and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_db_instances_with_low_cpu_utilization.md")
  tags          = merge(local.sql_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.sql_db_instances_with_low_cpu_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_cpu_utilization_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_db_instances_low_cpu_utilization_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_db_instances_with_low_cpu_utilization
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

pipeline "correct_sql_db_instances_with_low_cpu_utilization" {
  title         = "Correct SQL DB instances with low cpu utilization"
  description   = "Runs corrective action on a collection of SQL DB instances with low cpu utilization."
  documentation = file("./pipelines/sql/docs/correct_sql_db_instances_with_low_cpu_utilization.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title         = string
      instance_name = string
      project       = string
      conn          = string
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
    default     = var.sql_db_instances_with_low_cpu_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_cpu_utilization_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} SQL DB instances with low cpu utilization."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_db_instance_with_low_cpu_utilization
    args = {
      instance_name      = each.value.instance_name
      project            = each.value.project
      title              = each.value.title
      conn               = connection.gcp[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_sql_db_instance_with_low_cpu_utilization" {
  title         = "Correct one SQL DB instance with low cpu utilization"
  description   = "Runs corrective action on a SQL DB instance with low cpu utilization."
  documentation = file("./pipelines/sql/docs/correct_one_sql_db_instance_with_low_cpu_utilization.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "instance_name" {
    type        = string
    description = "The name of the SQL DB instance."
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "project" {
    type        = string
    description = local.description_project
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
    default     = var.sql_db_instances_with_low_cpu_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_cpu_utilization_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL DB instance ${param.title} with low cpu utilization."
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
            text     = "Skipped SQL DB instance ${param.title} with low cpu utilization."
          }
          success_msg = "Skipped SQL DB instance ${param.title}."
          error_msg   = "Error skipping SQL DB instance ${param.title}."
        },
        "stop_sql_instance" = {
          label        = "Stop Instance"
          value        = "stop_sql_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_stop_sql_instance
          pipeline_args = {
            conn          = param.conn
            project_id    = param.project
            instance_name = param.instance_name
          }
          success_msg = "Stopped SQL DB instance ${param.title}."
          error_msg   = "Error stopping SQL DB instance ${param.title}."
        },
        "delete_instance" = {
          label        = "Delete Instance"
          value        = "delete_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_sql_instance
          pipeline_args = {
            conn          = param.conn
            instance_name = param.instance_name
            project_id    = param.project
          }
          success_msg = "Deleted SQL DB instance ${param.title}."
          error_msg   = "Error deleting SQL DB instance ${param.title}."
        }
      }
    }
  }
}

variable "sql_db_instances_with_low_cpu_utilization_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "sql_db_instances_with_low_cpu_utilization_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "sql_db_instances_with_low_cpu_utilization_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "sql_db_instances_with_low_cpu_utilization_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_sql_instance", "delete_instance"]
}

variable "alarm_threshold" {
  type        = number
  description = "The threshold for cpu utilization to trigger an alarm."
  default     = 25
}
