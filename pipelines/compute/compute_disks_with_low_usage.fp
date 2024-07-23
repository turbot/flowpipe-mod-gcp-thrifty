locals {
  compute_disks_with_low_usage_query = <<-EOQ
    with disk_usage as (
      select
        project,
        location as zone,
        name as disk_name,
        _ctx,
        round(avg(max)) as avg_max,
        count(max) as days
      from
        (
          select
            project,
            name,
            location,
            _ctx,
            cast(maximum as numeric) as max
          from
            gcp_compute_disk_metric_read_ops_daily
          where
            date_part('day', now() - timestamp) <= 30
          union all
          select
            project,
            name,
            location,
            _ctx,
            cast(maximum as numeric) as max
          from
            gcp_compute_disk_metric_write_ops_daily
          where
            date_part('day', now() - timestamp) <= 30
        ) as read_and_write_ops
      group by
        name,
        project,
        _ctx,
        location
    )
    select
      concat(disk_name, ' [', zone, '/', project, ']') as title,
      disk_name,
      project,
      zone,
      _ctx ->> 'connection_name' as cred
    from
      disk_usage
    where
      avg_max < ${var.compute_disks_with_low_usage_min};
  EOQ
}

trigger "query" "detect_and_correct_compute_disks_with_low_usage" {
  title         = "Detect & correct Compute disks with low usage"
  description   = "Detects Compute disks with low usage and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_low_usage_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_with_low_usage_trigger_enabled
  schedule = var.compute_disks_with_low_usage_trigger_schedule
  database = var.database
  sql      = local.compute_disks_with_low_usage_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_with_low_usage
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_with_low_usage" {
  title         = "Detect & correct Compute disks with low usage"
  description   = "Detects Compute disks with low usage and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_with_low_usage.md")
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
    default     = var.compute_disks_with_low_usage_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_with_low_usage_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_with_low_usage
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

pipeline "correct_compute_disks_with_low_usage" {
  title         = "Correct Compute disks with low usage"
  description   = "Runs corrective action on a collection of Compute disks with low usage."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_with_low_usage.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      disk_name = string
      project   = string
      zone      = string
      cred      = string
      title     = string
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
    default     = var.compute_disks_with_low_usage_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute disks with low usage."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_with_low_usage
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

pipeline "correct_one_compute_disk_with_low_usage" {
  title         = "Correct one Compute disk with low usage"
  description   = "Runs corrective action on a Compute disk with low usage."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_with_low_usage.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
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

  param "title" {
    type        = string
    description = local.description_title
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
    default     = var.compute_disks_with_low_usage_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_with_low_usage_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.title} with low usage."
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
            text     = "Skipped Compute disk ${param.title} with low usage."
          }
          success_msg = "Skipped Compute disk ${param.title}."
          error_msg   = "Error skipping Compute disk ${param.title}."
        },
        "delete_disk" = {
          label        = "Delete Compute disk"
          value        = "delete_disk"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_compute_disk
          pipeline_args = {
            project_id = param.project
            zone       = param.zone
            disk_name  = param.disk_name
            cred       = param.cred
          }
          success_msg = "Deleted Compute disk ${param.title}."
          error_msg   = "Error deleting Compute disk ${param.title}."
        }
        "snapshot_and_delete_compute_disk" = {
          label        = "Snapshot & delete Compute disk"
          value        = "snapshot_and_delete_compute_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_and_delete_compute_disk
          pipeline_args = {
            disk_name = param.disk_name
            zone      = param.zone
            project   = param.project
            cred      = param.cred
          }
          success_msg = "Snapshotted & deleted Compute disk ${param.title}."
          error_msg   = "Error snapshotting & deleting Compute disk ${param.title}."
        }
      }
    }
  }
}

variable "compute_disks_with_low_usage_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disks_with_low_usage_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_disks_with_low_usage_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disks_with_low_usage_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_disk", "snapshot_and_delete_compute_disk"]
}

variable "compute_disks_with_low_usage_min" {
  type        = number
  description = "The number of average read/write ops required for disks to be considered infrequently used."
  default     = 100
}
