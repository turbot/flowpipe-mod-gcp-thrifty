locals {
  compute_instances_exceeding_max_age_query = <<-EOQ
    select
      concat(name, ' [', zone, '/', project, ']') as title,
      name as instance_name,
      zone,
      sp_connection_name as conn,
      project
    from
      gcp_compute_instance
    where
      status in ('PROVISIONING', 'STAGING', 'RUNNING', 'REPAIRING')
      and date_part('day', now() - creation_timestamp) > ${var.compute_instances_exceeding_max_age_days};
  EOQ

  compute_instances_exceeding_max_age_enabled_actions = ["skip", "stop_instance", "terminate_instance"]
  compute_instances_exceeding_max_age_default_action  = ["notify", "skip", "stop_instance", "terminate_instance"]
}

variable "compute_instances_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_exceeding_max_age_days" {
  type        = number
  description = "The maximum age (in days) for an instance to be considered long-running."
  default     = 30
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "stop_instance", "terminate_instance"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_instance", "terminate_instance"]
  enum        = ["skip", "stop_instance", "terminate_instance"]

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_instances_exceeding_max_age" {
  title         = "Detect & correct Compute engine instances exceeding max age"
  description   = "Identifies Compute engine instances exceeding max age and executes the chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_exceeding_max_age_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_instances_exceeding_max_age_trigger_enabled
  schedule = var.compute_instances_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.compute_instances_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_compute_instances_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_instances_exceeding_max_age" {
  title         = "Detect & correct Compute engine instances exceeding max age"
  description   = "Detects Compute engine instances exceeding max age and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.compute_instances_exceeding_max_age_default_action
    enum        = local.compute_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_exceeding_max_age_enabled_actions
    enum        = local.compute_instances_exceeding_max_age_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_instances_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_instances_exceeding_max_age
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

pipeline "correct_compute_instances_exceeding_max_age" {
  title         = "Correct Compute engine instances exceeding max age"
  description   = "Executes corrective actions on Compute engine instances exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_compute_instances_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused", class = "internal" })

  param "items" {
    type = list(object({
      title         = string
      conn          = string
      instance_name = string
      zone          = string
      project       = string
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
    default     = var.compute_instances_exceeding_max_age_default_action
    enum        = local.compute_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_exceeding_max_age_enabled_actions
    enum        = local.compute_instances_exceeding_max_age_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute engine instances exceeding max age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_instance_exceeding_max_age
    args = {
      instance_name      = each.value.instance_name
      zone               = each.value.zone
      project            = each.value.project
      conn               = connection.gcp[each.value.conn]
      title              = each.value.title
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_instance_exceeding_max_age" {
  title         = "Correct one Compute engine instance exceeding max age"
  description   = "Runs corrective action on a single Compute engine instance exceeding max age."
  documentation = file("./pipelines/compute/docs/correct_one_compute_instance_exceeding_max_age.md")
  tags          = merge(local.compute_common_tags, { class = "unused", class = "internal" })

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "instance_name" {
    type        = string
    description = "The name of the Compute engine instance."
  }

  param "zone" {
    type        = string
    description = local.description_zone
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
    default     = var.compute_instances_exceeding_max_age_default_action
    enum        = local.compute_instances_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_exceeding_max_age_enabled_actions
    enum        = local.compute_instances_exceeding_max_age_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute engine instance ${param.title} exceeding max age."
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
            text     = "Skipped Compute engine instance ${param.title} exceeding max age."
          }
          success_msg = "Skipped Compute engine instance ${param.title}."
          error_msg   = "Error skipping Compute engine instance ${param.title}."
        },
        "stop_instance" = {
          label        = "Stop Instance"
          value        = "stop_instance"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.stop_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            zone          = param.zone
            project_id    = param.project
            conn          = param.conn
          }
          success_msg = "Stopped Compute engine instance ${param.title}."
          error_msg   = "Error stopping Compute engine instance ${param.title}."
        },
        "terminate_instance" = {
          label        = "Terminate Instance"
          value        = "terminate_instance"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            zone          = param.zone
            project_id    = param.project
            conn          = param.conn
          }
          success_msg = "Deleted Compute engine instance ${param.title}."
          error_msg   = "Error deleting Compute engine instance ${param.title}."
        }
      }
    }
  }
}
