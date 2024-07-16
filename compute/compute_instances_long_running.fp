locals {
  compute_instance_long_running_query = <<-EOQ
    select
      concat(name, ' [', zone, '/', project, ']') as title,
      name as instance_name,
      zone,
      _ctx ->> 'connection_name' as cred,
      project
    from
      gcp_compute_instance
    where
      status in ('PROVISIONING', 'STAGING', 'RUNNING', 'REPAIRING')
      and date_part('day', now() - creation_timestamp) > ${var.compute_instances_exceeding_max_age_days};
  EOQ
}

trigger "query" "detect_and_correct_compute_instance_long_running" {
  title         = "Detect & correct long-running Compute engine instances"
  description   = "Identifies long-running Compute engine instances and executes the chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_instances_long_running_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_instances_long_running_trigger_enabled
  schedule = var.compute_instances_long_running_trigger_schedule
  database = var.database
  sql      = local.compute_instance_long_running_query

  capture "insert" {
    pipeline = pipeline.correct_compute_instance_long_running
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_instance_long_running" {
  title         = "Detect & correct long-running Compute engine instances"
  description   = "Detects long-running Compute engine instances and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_instances_long_running.md")
  tags          = merge(local.compute_common_tags, { class = "unused", type = "featured" })

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
    default     = var.compute_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_long_running_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_instance_long_running_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_instance_long_running
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

pipeline "correct_compute_instance_long_running" {
  title         = "Correct long-running Compute engine instances"
  description   = "Executes corrective actions on long-running Compute engine instances."
  documentation = file("./compute/docs/correct_compute_instance_long_running.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title         = string
      cred          = string
      instance_name = string
      zone          = string
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
    default     = var.compute_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_long_running_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} long-running Compute engine instances."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_instance_long_running
    args = {
      instance_name      = each.value.instance_name
      zone               = each.value.zone
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

pipeline "correct_one_compute_instance_long_running" {
  title         = "Correct one long-running Compute engine instance"
  description   = "Runs corrective action on a single long-running Compute engine instance."
  documentation = file("./compute/docs/correct_one_compute_instance_long_running.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "cred" {
    type        = string
    description = local.description_credential
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
    default     = var.compute_instances_long_running_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_long_running_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected long-running Compute engine instance ${param.title}."
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
            text     = "Skipped long-running Compute engine instance ${param.title}."
          }
          success_msg = "Skipped Compute engine instance ${param.title}."
          error_msg   = "Error skipping Compute engine instance ${param.title}."
        },
        "stop_instance" = {
          label        = "Stop Instance"
          value        = "stop_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_stop_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            zone          = param.zone
            project_id    = param.project
            cred          = param.cred
          }
          success_msg = "Stopped Compute engine instance ${param.title}."
          error_msg   = "Error stopping Compute engine instance ${param.title}."
        },
        "terminate_instance" = {
          label        = "Terminate Instance"
          value        = "terminate_instance"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_terminate_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            zone          = param.zone
            project_id    = param.project
            cred          = param.cred
          }
          success_msg = "Deleted Compute engine instance ${param.title}."
          error_msg   = "Error deleting Compute engine instance ${param.title}."
        }
      }
    }
  }
}

variable "compute_instances_long_running_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_instances_long_running_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_instances_exceeding_max_age_days" {
  type        = number
  description = "The maximum age (in days) for an instance to be considered long-running."
  default     = 30
}

variable "compute_instances_long_running_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_instances_long_running_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_instance", "terminate_instance"]
}