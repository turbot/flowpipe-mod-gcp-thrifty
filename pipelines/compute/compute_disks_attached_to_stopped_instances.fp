locals {
  compute_disks_attached_to_stopped_instances_query = <<-EOQ
    select
      concat(d.name, ' [', d.zone, '/', d.project, ']') as title,
      d.name as disk_name,
      d.zone as zone,
      d.project as project,
      d.sp_connection_name as conn,
      i.name as instance_name
    from
      gcp_compute_disk as d
      left join gcp_compute_instance as i on d.users ?& ARRAY [i.self_link]
    where
      d.users is not null
      and i.status != 'RUNNING';
  EOQ

  compute_disks_attached_to_stopped_instances_enabled_actions = ["skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_detach_and_delete_disk"]
  compute_disks_attached_to_stopped_instances_default_action  = ["notify", "skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_detach_and_delete_disk"]
}

variable "compute_disks_attached_to_stopped_instances_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_attached_to_stopped_instances_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_attached_to_stopped_instances_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_detach_and_delete_disk"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_disks_attached_to_stopped_instances_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_detach_and_delete_disk"]
  enum        = ["skip", "detach_disk", "detach_and_delete_compute_disk", "snapshot_detach_and_delete_disk"]

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_disks_attached_to_stopped_instances" {
  title         = "Detect & correct Compute disks attached to stopped instances"
  description   = "Detects Compute disks attached to stopped instances and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_attached_to_stopped_instances_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_disks_attached_to_stopped_instances_trigger_enabled
  schedule = var.compute_disks_attached_to_stopped_instances_trigger_schedule
  database = var.database
  sql      = local.compute_disks_attached_to_stopped_instances_query

  capture "insert" {
    pipeline = pipeline.correct_compute_disks_attached_to_stopped_instances
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_disks_attached_to_stopped_instances" {
  title         = "Detect & correct Compute disks attached to stopped instances"
  description   = "Detects Compute disks attached to stopped instances and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_disks_attached_to_stopped_instances.md")
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
    default     = var.compute_disks_attached_to_stopped_instances_default_action
    enum        = local.compute_disks_attached_to_stopped_instances_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_attached_to_stopped_instances_enabled_actions
    enum        = local.compute_disks_attached_to_stopped_instances_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_disks_attached_to_stopped_instances_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_disks_attached_to_stopped_instances
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

pipeline "correct_compute_disks_attached_to_stopped_instances" {
  title         = "Correct Compute disks attached to stopped instances"
  description   = "Runs corrective action on a collection of Compute disks attached to stopped instance."
  documentation = file("./pipelines/compute/docs/correct_compute_disks_attached_to_stopped_instances.md")
  tags          = merge(local.compute_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      disk_name     = string
      zone          = string
      instance_name = string
      project       = string
      conn          = string
      title         = string
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
    default     = var.compute_disks_attached_to_stopped_instances_default_action
    enum        = local.compute_disks_attached_to_stopped_instances_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_attached_to_stopped_instances_enabled_actions
    enum        = local.compute_disks_attached_to_stopped_instances_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute disks attached to stopped instances."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_disk_attached_to_stopped_instance
    args = {
      disk_name          = each.value.disk_name
      project            = each.value.project
      zone               = each.value.zone
      instance_name      = each.value.instance_name
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

pipeline "correct_one_compute_disk_attached_to_stopped_instance" {
  title         = "Correct one Compute disk attached to stopped instance"
  description   = "Runs corrective action on a Compute disk attached to a stopped instance."
  documentation = file("./pipelines/compute/docs/correct_one_compute_disk_attached_to_stopped_instance.md")
  tags          = merge(local.compute_common_tags, { class = "unused", folder = "Internal" })

  param "project" {
    type        = string
    description = local.description_project
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "instance_name" {
    type        = string
    description = "The name of the instance to which the disk is attached."
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
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
    default     = var.compute_disks_attached_to_stopped_instances_default_action
    enum        = local.compute_disks_attached_to_stopped_instances_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_disks_attached_to_stopped_instances_enabled_actions
    enum        = local.compute_disks_attached_to_stopped_instances_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Compute disk ${param.disk_name} attached to stopped instance ${param.instance_name}."
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
            text     = "Skipped Compute disk ${param.disk_name} attached to stopped instance ${param.instance_name}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_disk" = {
          label        = "Detach disk"
          value        = "detach_disk"
          style        = local.style_info
          pipeline_ref = gcp.pipeline.detach_compute_disk_from_instance
          pipeline_args = {
            disk_name     = param.disk_name
            project_id    = param.project
            zone          = param.zone
            instance_name = param.instance_name
            conn          = param.conn
          }
          success_msg = "Detached Compute disk ${param.disk_name} from the instance ${param.instance_name}."
          error_msg   = "Error detaching Compute disk ${param.disk_name} from the instance ${param.instance_name}."
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
            conn          = param.conn
          }
          success_msg = "Detached & deleted Compute disk ${param.disk_name}."
          error_msg   = "Error detaching and deleting Compute disk ${param.disk_name}."
        },
        "snapshot_detach_and_delete_disk" = {
          label        = "Snapshot, Detach & Delete Disk"
          value        = "snapshot_detach_and_delete_disk"
          style        = local.style_alert
          pipeline_ref = pipeline.snapshot_detach_and_delete_disk
          pipeline_args = {
            disk_name     = param.disk_name
            project       = param.project
            instance_name = param.instance_name
            zone          = param.zone
            conn          = param.conn
          }
          success_msg = "Snapshotted, detached & deleted Compute disk ${param.disk_name}."
          error_msg   = "Error snapshotting & deleting Compute disk ${param.disk_name}."
        }
      }
    }
  }
}

pipeline "detach_and_delete_compute_disk" {
  title       = "Detach & delete Compute disk"
  description = "A utility pipeline which snapshots and deletes a Compute disk."
  tags        = merge(local.compute_common_tags, { folder = "Internal" })

  param "instance_name" {
    type        = string
    description = "The name of the Compute Instance."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  step "pipeline" "detach_compute_disk" {
    pipeline = gcp.pipeline.detach_compute_disk_from_instance
    args = {
      disk_name     = param.disk_name
      instance_name = param.instance_name
      project_id    = param.project
      zone          = param.zone
      conn          = param.conn
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.detach_compute_disk]
    pipeline   = gcp.pipeline.delete_compute_disk
    args = {
      disk_name  = param.disk_name
      project_id = param.project
      zone       = param.zone
      conn       = param.conn
    }
  }
}

pipeline "snapshot_detach_and_delete_disk" {
  title       = "Snapshot & Detach & Delete Compute disk"
  description = "A utility pipeline which snapshots and deletes a Compute disk."
  tags        = merge(local.compute_common_tags, { folder = "Internal" })

  param "project" {
    type        = string
    description = local.description_project
  }

  param "disk_name" {
    type        = string
    description = "The name of the Compute disk."
  }

  param "instance_name" {
    type        = string
    description = "The name of the instance to which the disk is attached."
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  step "pipeline" "create_compute_snapshot" {
    pipeline = gcp.pipeline.create_compute_snapshot
    args = {
      source_disk_name = param.disk_name
      source_disk_zone = param.zone
      project_id       = param.project
      snapshot_name    = "snapshot-${param.disk_name}"
      conn             = param.conn
    }
  }

  step "pipeline" "detach_compute_disk" {
    depends_on = [step.pipeline.create_compute_snapshot]
    pipeline   = gcp.pipeline.detach_compute_disk_from_instance
    args = {
      disk_name     = param.disk_name
      instance_name = param.instance_name
      project_id    = param.project
      zone          = param.zone
      conn          = param.conn
    }
  }

  step "pipeline" "delete_compute_disk" {
    depends_on = [step.pipeline.detach_compute_disk]
    pipeline   = gcp.pipeline.delete_compute_disk
    args = {
      disk_name  = param.disk_name
      project_id = param.project
      zone       = param.zone
      conn       = param.conn
    }
  }
}
