locals {
  compute_addresses_if_unattached_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name as address_name,
      location,
      sp_connection_name as conn,
      project
    from
      gcp_compute_address
    where
      status != 'IN_USE';
  EOQ
}

trigger "query" "detect_and_correct_compute_addresses_if_unattached" {
  title         = "Detect & correct Compute addresses if unattached"
  description   = "Detects unattached Compute addresses and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_addresses_if_unattached_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_addresses_if_unattached_trigger_enabled
  schedule = var.compute_addresses_if_unattached_trigger_schedule
  database = var.database
  sql      = local.compute_addresses_if_unattached_query

  capture "insert" {
    pipeline = pipeline.correct_compute_addresses_if_unattached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_addresses_if_unattached" {
  title         = "Detect & correct Compute addresses if unattached"
  description   = "Detects unattached Compute addresses and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_addresses_if_unattached.md")
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
    default     = var.compute_addresses_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_addresses_if_unattached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_addresses_if_unattached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_addresses_if_unattached
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

pipeline "correct_compute_addresses_if_unattached" {
  title         = "Correct Compute addresses if unattached"
  description   = "Runs corrective action on a collection of Compute addresses that are unattached."
  documentation = file("./pipelines/compute/docs/correct_compute_addresses_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      address_name = string
      title        = string
      conn         = string
      location     = string
      project      = string
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
    default     = var.compute_addresses_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_addresses_if_unattached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} unattached Compute addresses."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_address_if_unattached
    args = {
      address_name       = each.value.address_name
      location           = each.value.location
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

pipeline "correct_one_compute_address_if_unattached" {
  title         = "Correct one Compute address if unattached"
  description   = "Runs corrective action on one Compute address that is unattached."
  documentation = file("./pipelines/compute/docs/correct_one_compute_address_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "address_name" {
    type        = string
    description = "The name of the Compute address."
  }

  param "location" {
    type        = string
    description = local.description_location
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
    default     = var.compute_addresses_if_unattached_default_action
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_addresses_if_unattached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected unattached Compute address ${param.title}."
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
            text     = "Skipped unattached Compute address ${param.title}."
          }
          success_msg = "Skipped Compute address ${param.title}."
          error_msg   = "Error skipping Compute address ${param.title}."
        },
        "delete" = {
          label        = "Delete Compute Address"
          value        = "delete"
          style        = local.style_ok
          pipeline_ref = gcp.pipeline.delete_compute_address
          pipeline_args = {
            address_name = param.address_name
            region       = param.location
            project_id   = param.project
            conn         = param.conn
          }
          success_msg = "Deleted Compute address ${param.title}."
          error_msg   = "Error releasing Compute address ${param.title}."
        }
      }
    }
  }
}

variable "compute_addresses_if_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_addresses_if_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_addresses_if_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_addresses_if_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete"]
  tags = {
    folder = "Advanced/Compute"
  }
}
