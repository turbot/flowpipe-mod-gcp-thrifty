locals {
  compute_addresses_if_unattached_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name as address_name,
      location,
      _ctx ->> 'connection_name' as cred,
      project
    from
      gcp_compute_address
    where
      status != 'IN_USE';
  EOQ
}

trigger "query" "detect_and_correct_compute_addresses_if_unattached" {
  title         = "Detect & correct Compute Addresses if unattached"
  description   = "Detects unattached Compute Addresses and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_addresses_if_unattached_trigger.md")
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
  title         = "Detect & correct Compute Addresses if unattached"
  description   = "Detects unattached Compute Addresses and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_addresses_if_unattached.md")
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
  title         = "Correct Compute Addresses if unattached"
  description   = "Runs corrective action on a collection of Compute Addresses which are unattached."
  documentation = file("./compute/docs/correct_compute_addresses_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      address_name = string
      title        = string
      cred         = string
      location     = string
      project      = string
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
    default     = var.compute_addresses_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_addresses_if_unattached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute Addresses unattached."
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

pipeline "correct_one_compute_address_if_unattached" {
  title         = "Correct one Compute Address if unattached"
  description   = "Runs corrective action on one Compute Address which is unattached."
  documentation = file("./compute/docs/correct_one_compute_address_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "address_name" {
    type        = string
    description = "The name of the Compute Address."
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
    default     = var.compute_addresses_if_unattached_default_action
  }

  param "cred" {
    type        = string
    description = local.description_credential
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
      detect_msg         = "Detected Compute Address ${param.title} unattached."
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
            text     = "Skipped Compute Address ${param.title} unattached."
          }
          success_msg = "Skipped Compute Address ${param.title}."
          error_msg   = "Error skipping Compute Address ${param.title}."
        },
        "release" = {
          label        = "Release"
          value        = "release"
          style        = local.style_ok
          pipeline_ref = local.gcp_pipeline_delete_compute_address
          pipeline_args = {
            address_name = param.address_name
            region       = param.location
            project_id   = param.project
            cred         = param.cred
          }
          success_msg = "Released Compute Address ${param.title}."
          error_msg   = "Error releasing Compute Address ${param.title}."
        }
      }
    }
  }
}

variable "compute_addresses_if_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_addresses_if_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_addresses_if_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_addresses_if_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "release"]
}