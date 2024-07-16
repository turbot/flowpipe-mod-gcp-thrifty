locals {
  compute_disks_if_unattached_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name as disk_name,
      project,
      _ctx ->> 'connection_name' as cred,
      zone
    from
      gcp_compute_disk
    where
      users is null;
  EOQ
}

trigger "query" "detect_and_correct_compute_disks_if_unattached" {
  title         = "Detect & correct compute disks if unattached"
  description   = "Detects compute disks which are unattached and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_if_unattached_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_if_unattached_trigger_enabled
  schedule = var.compute_disks_if_unattached_trigger_schedule
  database = var.database
  sql      = local.compute_disks_if_unattached_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_if_unattached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_if_unattached" {
  title         = "Detect & correct compute disks if unattached"
  description   = "Detects compute disks which are unattached and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disks_if_unattached.md")
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_if_unattached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_if_unattached
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

pipeline "correct_compute_disks_if_unattached" {
  title         = "Correct compute disks if unattached"
  description   = "Runs corrective action on a collection of compute disks which are unattached."
  documentation = file("./compute/docs/correct_compute_disks_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      cred      = string
      title     = string
      disk_name = string
      project   = string
      zone      = string
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} unattached compute disk(s)."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_if_unattached
    args = {
      disk_name          = each.value.disk_name
      project            = each.value.project
      zone               = each.value.zone
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

pipeline "correct_one_compute_disk_if_unattached" {
  title         = "Correct one compute disk if unattached"
  description   = "Runs corrective action on a compute disk unattached."
  documentation = file("./compute/docs/correct_one_compute_disk_if_unattached.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = "The title of the compute disk."
  }

  param "disk_name" {
    type        = string
    description = "Compute disk name."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "zone" {
    type        = string
    description = local.description_zone
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
    default     = var.compute_disks_if_unattached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_if_unattached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected compute disk ${param.title} unattached."
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
            text     = "Skipped compute disk ${param.title} unattached."
          }
          success_msg = "Skipped compute disk ${param.title}."
          error_msg   = "Error skipping compute disk ${param.title}."
        },
        "delete_compute_disk" = {
          label        = "Delete Compute disk"
          value        = "delete_compute_disk"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_compute_disk
          pipeline_args = {
            disk_name  = param.disk_name
            zone       = param.zone
            project_id = param.project
            cred       = param.cred
          }
          success_msg = "Deleted compute disk ${param.title}."
          error_msg   = "Error deleting compute disk ${param.title}."
        }
        "snapshot_and_delete_compute_disk" = {
          label        = "Snapshot & Delete Compute disk"
          value        = "snapshot_and_delete_compute_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_and_delete_compute_disk
          pipeline_args = {
            disk_name = param.disk_name
            zone      = param.zone
            project   = param.project
            cred      = param.cred
          }
          success_msg = "Snapshotted & Deleted compute disk ${param.title}."
          error_msg   = "Error snapshotting & deleting compute disk ${param.title}."
        }
      }
    }
  }
}

pipeline "snapshot_and_delete_compute_disk" {
  title       = "Snapshot & Delete Compute disk"
  description = "A utility pipeline which snapshots and deletes a compute disk."

  param "disk_name" {
    type        = string
    description = "Compute disk name."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  step "pipeline" "create_compute_snapshot" {
    pipeline = local.gcp_pipeline_create_compute_snapshot
    args = {
      source_disk_name = param.disk_name
      source_disk_zone = param.zone
      snapshot_name    = "snapshot-${param.title}"
      project_id       = param.project
      cred             = param.cred
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.create_compute_snapshot]
    pipeline   = local.gcp_pipeline_delete_compute_disk
    args = {
      disk_name  = param.disk_name
      zone       = param.zone
      project_id = param.project
      cred       = param.cred
    }
  }
}

variable "compute_disks_if_unattached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disks_if_unattached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_disks_if_unattached_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disks_if_unattached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_compute_disk", "snapshot_and_delete_compute_disk"]
}