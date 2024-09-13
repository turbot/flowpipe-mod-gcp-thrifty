locals {
  sql_db_instances_with_low_connection_count_query = <<-EOQ
    with sql_db_instance_usage as (
      select
        instance_id,
        round(sum(maximum) / count(maximum)) as avg_max,
        count(maximum) as days
      from
        gcp_sql_database_instance_metric_connections_daily
      where
        date_part('day', now() - timestamp) <= 30
      group by
        instance_id
    )
    select
      concat(i.name, ' [', i.location, '/', i.project, ']') as title,
      i.name as instance_name,
      i.project as project,
      i._ctx ->> 'connection_name' as cred
    from
      gcp_sql_database_instance as i
      left join sql_db_instance_usage as u on i.project || ':' || i.name = u.instance_id
    where
      u.avg_max = 0;
  EOQ
}

trigger "query" "detect_and_correct_sql_db_instances_with_low_connection_count" {
  title         = "Detect & correct SQL DB instances with low connection count"
  description   = "Detects SQL DB instances with low connection count and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_db_instances_with_low_connection_count_trigger.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  enabled  = var.sql_db_instances_with_low_connection_count_trigger_enabled
  schedule = var.sql_db_instances_with_low_connection_count_trigger_schedule
  database = var.database
  sql      = local.sql_db_instances_with_low_connection_count_query

  capture "insert" {
    pipeline = pipeline.correct_sql_db_instances_with_low_connection_count
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_sql_db_instances_with_low_connection_count" {
  title         = "Detect & correct SQL DB instances with low connection count"
  description   = "Detects SQL DB instances with low connection count and runs your chosen action."
  documentation = file("./pipelines/sql/docs/detect_and_correct_sql_db_instances_with_low_connection_count.md")
  tags          = merge(local.sql_common_tags, { class = "unused", type = "recommended" })

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
    default     = var.sql_db_instances_with_low_connection_count_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_connection_count_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.sql_db_instances_with_low_connection_count_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_sql_db_instances_with_low_connection_count
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

pipeline "correct_sql_db_instances_with_low_connection_count" {
  title         = "Correct SQL DB instances with low connection count"
  description   = "Runs corrective action on a collection of SQL DB instances with low connection count."
  documentation = file("./pipelines/sql/docs/correct_sql_db_instances_with_low_connection_count.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      instance_name = string
      title         = string
      cred          = string
      project       = string
    }))
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
    default     = var.sql_db_instances_with_low_connection_count_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_connection_count_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} SQL DB instances with low connection count."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_sql_db_instance_with_low_connection_count
    args = {
      instance_name      = each.value.instance_name
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

pipeline "correct_one_sql_db_instance_with_low_connection_count" {
  title         = "Correct one SQL DB instance with low connection count"
  description   = "Runs corrective action on a SQL DB instance with low connection count."
  documentation = file("./pipelines/sql/docs/correct_one_sql_db_instance_with_low_connection_count.md")
  tags          = merge(local.sql_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "instance_name" {
    type        = string
    description = "The name of the SQL DB instance."
  }

  param "project" {
    type        = string
    description = local.description_project
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
    default     = var.sql_db_instances_with_low_connection_count_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.sql_db_instances_with_low_connection_count_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected SQL DB instance ${param.title} with low connection count."
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
            text     = "Skipped SQL DB Instance ${param.title} with low connection count."
          }
          success_msg = "Skipped SQL DB Instance ${param.title}."
          error_msg   = "Error skipping SQL DB Instance ${param.title}."
        },
        "delete_instance" = {
          label        = "Delete Instance"
          value        = "delete_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_sql_instance
          pipeline_args = {
            cred          = param.cred
            instance_name = param.instance_name
            project_id    = param.project
          }
          success_msg = "Deleted SQL DB Instance ${param.title}."
          error_msg   = "Error deleting SQL DB Instance ${param.title}."
        }
      }
    }
  }
}

variable "sql_db_instances_with_low_connection_count_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_db_instances_with_low_connection_count_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_db_instances_with_low_connection_count_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/SQL"
  }
}

variable "sql_db_instances_with_low_connection_count_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_instance"]
  tags = {
    folder = "Advanced/SQL"
  }
}