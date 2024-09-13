locals {
  compute_instances_large_query = <<-EOQ
    select
      concat(name, ' [', zone, '/', project, ']') as title,
      name as instance_name,
      zone,
      _ctx ->> 'connection_name' as cred,
      project
    from
      gcp_compute_instance
    where
      status in ('RUNNING', 'PROVISIONING', 'STAGING', 'REPAIRING')
      and machine_type_name not like any (array[${join(",", formatlist("'%s'", var.compute_instances_large_allowed_types))}])
  EOQ
}

trigger "query" "detect_and_correct_compute_instances_large" {
  title         = "Detect & correct Compute engine instances large"
  description   = "Identifies large Compute engine instances and executes the chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_large_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_instances_large_trigger_enabled
  schedule = var.compute_instances_large_trigger_schedule
  database = var.database
  sql      = local.compute_instances_large_query

  capture "insert" {
    pipeline = pipeline.correct_compute_instances_large
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_instances_large" {
  title         = "Detect & correct Compute engine instances large"
  description   = "Detects large Compute engine instances and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_large.md")
  tags          = merge(local.compute_common_tags, { class = "unused", type = "recommended" })

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
    default     = var.compute_instances_large_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_large_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_instances_large_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_instances_large
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

pipeline "correct_compute_instances_large" {
  title         = "Correct Compute engine instances large"
  description   = "Executes corrective actions on large Compute engine instances."
  documentation = file("./pipelines/compute/docs/correct_compute_instances_large.md")
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
    default     = var.compute_instances_large_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_large_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} large Compute engine instance."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_instance_large
    args = {
      instance_name      = each.value.instance_name
      zone               = each.value.zone
      cred               = each.value.cred
      title              = each.value.title
      project            = each.value.project
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_instance_large" {
  title         = "Correct one Compute engine instance large"
  description   = "Runs corrective action on a single large Compute engine instance."
  documentation = file("./pipelines/compute/docs/correct_one_compute_instance_large.md")
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
    default     = var.compute_instances_large_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_large_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected large Compute Engine Instance ${param.title}."
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
            text     = "Skipped large Compute Engine Instance ${param.title}."
          }
          success_msg = "Skipped Compute Engine Instance ${param.title}."
          error_msg   = "Error skipping Compute Engine Instance ${param.title}."
        },
        "stop_instance" = {
          label        = "Stop Compute Instance"
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
          label        = "Terminate Compute Instance"
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

variable "compute_instances_large_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_large_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_large_allowed_types" {
  type        = list(string)
  description = "A list of allowed instance types. PostgreSQL wildcards are supported."
  default     = ["custom-1-1024", "custom-2-2048", "custom-4-4096", "custom-8-8192", "custom-16-16384", "custom-32-32768", "custom-64-65536", "custom-96-98304", "custom-128-131072", "custom-224-229376"]
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_large_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_large_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_instance", "terminate_instance"]
  tags = {
    folder = "Advanced/Compute"
  }
}
