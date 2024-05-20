locals {
  compute_disk_attached_stopped_instance_query = <<-EOQ
    select
      d.name as disk_name,
      d.zone as zone,
      d.project as project,
      i.name as instance_name
    from
      gcp_compute_disk as d
      left join gcp_compute_instance as i on d.users ?& ARRAY [i.self_link]
    where
      d.users is not null
      and i.status != 'RUNNING';
  EOQ
}

trigger "query" "detect_and_correct_compute_disk_attached_stopped_instance" {
  title         = "Detect & correct Compute Disks attached to stopped instances"
  description   = "Detects Compute Disks attached to stopped instances and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disk_attached_to_stopped_instance_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disk_attached_stopped_instance_trigger_enabled
  schedule = var.compute_disk_attached_stopped_instance_trigger_schedule
  database = var.database
  sql      = local.compute_disk_attached_stopped_instance_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disk_attached_stopped_instance
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disk_attached_stopped_instance" {
  title         = "Detect & correct Compute Disks attached to stopped instances"
  description   = "Detects Compute Disks attached to stopped instances and runs your chosen action."
  documentation = file("./compute/docs/detect_and_correct_compute_disk_attached_to_stopped_instance.md")
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
    default     = var.compute_disk_attached_stopped_instance_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disk_attached_stopped_instance_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disk_attached_stopped_instance_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disk_attached_stopped_instance
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

pipeline "correct_compute_disk_attached_stopped_instance" {
  title         = "Correct Compute Disks attached to stopped instances"
  description   = "Runs corrective action on a collection of Compute Disks attached to stopped instance."
  documentation = file("./compute/docs/correct_compute_disk_attached_to_stopped_instance.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      disk_name     = string
      zone          = string
      instance_name = string
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
    default     = var.compute_disk_attached_stopped_instance_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disk_attached_stopped_instance_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Compute Disks attached to stopped instances."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.disk_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_attached_stopped_instance
    args = {
      disk_name          = each.value.disk_name
      project            = each.value.project
      zone               = each.value.zone
      instance_name      = each.value.instance_name
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_compute_disk_attached_stopped_instance" {
  title         = "Correct one Compute Disk attached to stopped instance"
  description   = "Runs corrective action on a Compute Disk attached to a stopped instance."
  documentation = file("./compute/docs/correct_one_compute_disk_attached_to_stopped_instance.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "project" {
    type        = string
    description = "The project of the Compute Disk."
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute Disk."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "instance_name" {
    type        = string
    description = "The name of the instance to which the disk is attached."
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
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
    default     = var.compute_disk_attached_stopped_instance_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disk_attached_stopped_instance_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute Disk ${param.disk_name} attached to stopped instance ${param.instance_name}."
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
            text     = "Skipped Compute Disk ${param.disk_name} attached to stopped instance ${param.instance_name}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_disk" = {
          label        = "Detach Disk"
          value        = "detach_disk"
          style        = local.style_info
          pipeline_ref = local.gcp_pipeline_detach_compute_disk
          pipeline_args = {
            disk_name     = param.disk_name
            project_id    = param.project
            zone          = param.zone
            instance_name = param.instance_name
            cred          = param.cred
          }
          success_msg = "Detached Compute Disk ${param.disk_name} from the instance ${param.instance_name}."
          error_msg   = "Error detaching Compute Disk ${param.disk_name} from the instance ${param.instance_name}."
        },
        "detach_and_delete_compute_disk" = {
          label        = "Detach & Delete Disk"
          value        = "detach_and_delete_compute_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.detach_and_delete_compute_disk
          pipeline_args = {
            disk_name     = param.disk_name
            project       = param.project
            instance_name = param.instance_name
            zone          = param.zone
            cred          = param.cred
          }
          success_msg = "Detached & Deleted Compute Disk ${param.disk_name}."
          error_msg   = "Error detaching and deleting Compute Disk ${param.disk_name}."
        },
        "snapshot_and_detach_and_delete_disk" = {
          label        = "Snapshot, Detached & Delete Disk"
          value        = "snapshot_and_detach_and_delete_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_and_detach_and_delete_disk
          pipeline_args = {
            disk_name     = param.disk_name
            project       = param.project
            instance_name = param.instance_name
            zone          = param.zone
            cred          = param.cred
          }
          success_msg = "Snapshotted, Detached & Deleted Compute Disk ${param.disk_name}."
          error_msg   = "Error snapshotting & deleting Compute Disk ${param.disk_name}."
        }
      }
    }
  }
}

pipeline "detach_and_delete_compute_disk" {
  title       = "Detach & Delete Compute Disk"
  description = "A utility pipeline which snapshots and deletes a Compute Disk."

  param "instance_name" {
    type        = string
    description = "The name of the Compute Instance."
  }

  param "project" {
    type        = string
    description = "The project of the Compute Disk."
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute Disk."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  step "pipeline" "detach_compute_disk" {
    pipeline = local.gcp_pipeline_detach_compute_disk
    args = {
      disk_name     = param.disk_name
      instance_name = param.instance_name
      project_id    = param.project
      zone          = param.zone
      cred          = param.cred
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.detach_compute_disk]
    pipeline   = local.gcp_pipeline_delete_compute_disk
    args = {
      disk_name  = param.disk_name
      project_id = param.project
      zone       = param.zone
      cred       = param.cred
    }
  }
}

pipeline "snapshot_and_detach_and_delete_disk" {
  title       = "Snapshot & Detach & Delete Compute Disk"
  description = "A utility pipeline which snapshots and deletes a Compute Disk."

  param "project" {
    type        = string
    description = "The project of the Compute Disk."
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute Disk."
  }

  param "instance_name" {
    type        = string
    description = "The name of the instance to which the disk is attached."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  step "pipeline" "create_compute_snapshot" {
    pipeline = local.gcp_pipeline_create_compute_snapshot
    args = {
      source_disk_name = param.disk_name
      source_disk_zone = param.zone
      project_id       = param.project
      snapshot_name    = "snapshot-${param.disk_name}"
      cred             = param.cred
    }
  }

  step "pipeline" "detach_compute_disk" {
    depends_on = [step.pipeline.create_compute_snapshot]
    pipeline   = local.gcp_pipeline_detach_compute_disk
    args = {
      disk_name     = param.disk_name
      instance_name = param.instance_name
      project_id    = param.project
      zone          = param.zone
      cred          = param.cred
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.detach_compute_disk]
    pipeline   = local.gcp_pipeline_delete_compute_disk
    args = {
      disk_name  = param.disk_name
      project_id = param.project
      zone       = param.zone
      cred       = param.cred
    }
  }
}

variable "compute_disk_attached_stopped_instance_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "compute_disk_attached_stopped_instance_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "compute_disk_attached_stopped_instance_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "compute_disk_attached_stopped_instance_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_and_detach_and_delete_disk"]
}
