locals {
  compute_disks_exceeding_max_size_query = <<-EOQ
  select
      concat(name, ' [', zone, '/', project, ']') as title,
      project,
      zone,
      name as disk_name,
      sp_connection_name as conn
    from
      gcp_compute_disk
    where
      size_gb > ${var.compute_disks_exceeding_max_size};
  EOQ

  compute_disks_exceeding_max_size_enabled_actions = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  compute_disks_exceeding_max_size_default_action  = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]
}

variable "compute_disks_exceeding_max_size_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_disk", "snapshot_and_delete_disk"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_disk"]
  enum        = ["skip", "delete_disk", "snapshot_and_delete_disk"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_exceeding_max_size" {
  type        = number
  description = "The maximum size (GB) allowed for disks."
  default     = 100
  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_disks_exceeding_max_size" {
  title         = "Detect & correct Compute disks exceeding max size"
  description   = "Detects Compute disks exceeding maximum size and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_exceeding_max_size_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "managed" })

  enabled  = var.compute_disks_exceeding_max_size_trigger_enabled
  schedule = var.compute_disks_exceeding_max_size_trigger_schedule
  database = var.database
  sql      = local.compute_disks_exceeding_max_size_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_exceeding_max_size
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_exceeding_max_size" {
  title         = "Detect & correct Compute disks exceeding max size"
  description   = "Detects Compute disks exceeding maximum size and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "managed", recommended = "true" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_exceeding_max_size_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_exceeding_max_size
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

pipeline "correct_compute_disks_exceeding_max_size" {
  title         = "Correct Compute disks exceeding max size"
  description   = "Runs corrective action on a collection of Compute disks exceeding maximum size."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "managed", folder = "Internal" })

  param "items" {
    type = list(object({
      project   = string
      zone      = string
      disk_name = string
      title     = string
      conn      = string
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disks exceeding maximum size."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_exceeding_max_size
    args = {
      project            = each.value.project
      zone               = each.value.zone
      disk_name          = each.value.disk_name
      notifier           = param.notifier
      conn               = connection.gcp[each.value.conn]
      title              = each.value.title
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_disk_exceeding_max_size" {
  title         = "Correct one Compute disk exceeding max size"
  description   = "Runs corrective action on a Compute disk exceeding maximum size."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_exceeding_max_size.md")
  tags          = merge(local.compute_common_tags, { class = "managed", folder = "Internal" })

  param "project" {
    type        = string
    description = local.description_project
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_disks_exceeding_max_size_default_action
    enum        = local.compute_disks_exceeding_max_size_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_exceeding_max_size_enabled_actions
    enum        = local.compute_disks_exceeding_max_size_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.disk_name} in project ${param.project} and zone ${param.zone} exceeding maximum size."
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
            text     = "Skipped Compute disk ${param.title} exceeding maximum size."
          }
          success_msg = "Skipped Compute disk ${param.title}."
          error_msg   = "Error skipping Compute disk ${param.title}."
        },
        "delete_disk" = {
          label        = "Delete Compute Disk"
          value        = "delete_disk"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_compute_disk
          pipeline_args = {
            project_id = param.project
            zone       = param.zone
            disk_name  = param.disk_name
            conn       = param.conn
          }
          success_msg = "deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        }
        "snapshot_and_delete_disk" = {
          label        = "Snapshot & Delete Compute Disk"
          value        = "snapshot_and_delete_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_and_delete_compute_disk
          pipeline_args = {
            project   = param.project
            zone      = param.zone
            disk_name = param.disk_name
            conn      = param.conn
          }
          success_msg = "Snapshotted & deleted Compute disk ${param.title}."
          error_msg   = "Error snapshotting & deleting Compute disk ${param.title}."
        }
      }
    }
  }
}
