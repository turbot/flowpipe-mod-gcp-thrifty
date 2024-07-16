locals {
  compute_node_groups_if_autoscaling_disabled_query = <<-EOQ
    select
      concat(name, ' [', zone, '/', project, ']') as title,
      name,
      zone,
      _ctx ->> 'connection_name' as cred,
      project
    from
      gcp_compute_node_group
    where
      autoscaling_policy_mode <> 'ON';
  EOQ
}

trigger "query" "detect_and_correct_compute_node_groups_if_autoscaling_disabled" {
  title         = "Detect & correct Compute node groups if autoscaling disabled"
  description   = "Detects Compute node groups if autoscaling disabled and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_node_groups_if_autoscaling_disabled_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_node_groups_if_autoscaling_disabled_trigger_enabled
  schedule = var.compute_node_groups_if_autoscaling_disabled_trigger_schedule
  database = var.database
  sql      = local.compute_node_groups_if_autoscaling_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_compute_node_groups_if_autoscaling_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_node_groups_if_autoscaling_disabled" {
  title         = "Detect & correct Compute node groups if autoscaling disabled"
  description   = "Detects Compute node groups if autoscaling disabled and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_node_groups_if_autoscaling_disabled.md")
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
    default     = var.compute_node_groups_if_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_node_groups_if_autoscaling_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_node_groups_if_autoscaling_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_node_groups_if_autoscaling_disabled
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

pipeline "correct_compute_node_groups_if_autoscaling_disabled" {
  title         = "Correct Compute node groups if autoscaling disabled"
  description   = "Runs corrective action on a collection of Compute node groups if autoscaling disabled."
  documentation = file("./compute/docs/correct_compute_node_groups_if_autoscaling_disabled.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      name    = string
      project = string
      zone    = string
      cred    = string
      title   = string
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
    default     = var.compute_node_groups_if_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_node_groups_if_autoscaling_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute node group autoscaling disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_node_group_if_autoscaling_disabled
    args = {
      name               = each.value.name
      project            = each.value.project
      title              = each.value.title
      cred               = each.value.cred
      zone               = each.value.zone
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_node_group_if_autoscaling_disabled" {
  title         = "Correct one Compute node group if autoscaling disabled"
  description   = "Runs corrective action on an Compute node group autoscaling disabled."
  documentation = file("./compute/docs/correct_one_compute_node_group_if_autoscaling_disabled.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "name" {
    type        = string
    description = "Compute Node Group Name."
  }

  param "max_nodes" {
    type        = number
    description = "Maximum number of nodes."
    default     = var.compute_node_group_max_nodes
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "zone" {
    type        = string
    description = local.description_zone
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
    default     = var.compute_node_groups_if_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_node_groups_if_autoscaling_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute node group ${param.title} autoscaling disabled."
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
            text     = "Skipped Compute node group ${param.title} autoscaling disabled."
          }
          success_msg = "Skipped Compute node group ${param.title}."
          error_msg   = "Error skipping Compute node group ${param.title}."
        },
        "enable_autoscaling_policy" = {
          label        = "Enable Autoscaling Policy"
          value        = "enable_autoscaling_policy"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_update_compute_node_group
          pipeline_args = {
            autoscaler_mode = "on"
            max_nodes       = param.max_nodes
            node_group_name = param.name
            project_id      = param.project
            zone            = param.zone
            cred            = param.cred
          }
          success_msg = "Enabled autoscaling policy for Compute node group ${param.title}."
          error_msg   = "Error enabling autoscaling policy for Compute node group ${param.title}."
        }
      }
    }
  }
}

variable "compute_node_group_max_nodes" {
  type        = number
  description = "The maximum number of nodes to set for the autoscaler."
  default     = 10
}

variable "compute_node_groups_if_autoscaling_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_node_groups_if_autoscaling_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_node_groups_if_autoscaling_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_node_groups_if_autoscaling_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_autoscaling_policy"]
}