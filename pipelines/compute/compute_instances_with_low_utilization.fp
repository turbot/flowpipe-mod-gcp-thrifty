locals {
  compute_instances_with_low_utilization_query = <<-EOQ
    with compute_instance_utilization as (
      select
        name,
        round(cast(sum(maximum) / count(maximum) as numeric), 1) as avg_max,
        count(maximum) as days
      from
        gcp_compute_instance_metric_cpu_utilization_daily
      where
        date_part('day', now() - timestamp :: timestamp) <= 30
      group by
        name
    )
    select
      concat(i.name, ' [', i.zone, '/', i.project, ']') as title,
      i.name as instance_name,
      i.project as project,
      i.sp_connection_name as conn,
      i.zone as zone
    from
      gcp_compute_instance as i
      left join compute_instance_utilization as u on u.name = i.name
    where
      avg_max is null or avg_max < ${var.compute_instances_with_low_utilization_avg_cpu_utilization};
  EOQ

  compute_instances_with_low_utilization_enabled_actions = ["skip", "stop_instance", "stop_downgrade_instance_type"]
  compute_instances_with_low_utilization_default_action  = ["notify", "skip", "stop_instance", "stop_downgrade_instance_type"]
}

variable "compute_instances_with_low_utilization_avg_cpu_utilization" {
  type        = number
  default     = 20
  description = "The average CPU utilization below which an instance is considered to have low utilization."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "machine_type" {
  type        = string
  default     = "e2-micro"
  description = "The machine type to downgrade to."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_with_low_utilization_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_with_low_utilization_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_with_low_utilization_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "stop_instance", "stop_downgrade_instance_type"]

  tags = {
    folder = "Advanced/Compute"
  }
}

variable "compute_instances_with_low_utilization_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "stop_instance", "stop_downgrade_instance_type"]
  enum        = ["skip", "stop_instance", "stop_downgrade_instance_type"]

  tags = {
    folder = "Advanced/Compute"
  }
}

trigger "query" "detect_and_correct_compute_instances_with_low_utilization" {
  title         = "Detect & correct Compute instances with low utilization"
  description   = "Detects Compute instances with low utilization and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_with_low_utilization_trigger.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  enabled  = var.compute_instances_with_low_utilization_trigger_enabled
  schedule = var.compute_instances_with_low_utilization_trigger_schedule
  database = var.database
  sql      = local.compute_instances_with_low_utilization_query

  capture "insert" {
    pipeline = pipeline.correct_compute_instances_with_low_utilization
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_compute_instances_with_low_utilization" {
  title         = "Detect & correct Compute instances with low utilization"
  description   = "Detects Compute instances with low utilization and runs your chosen action."
  documentation = file("./pipelines/compute/docs/detect_and_correct_compute_instances_with_low_utilization.md")
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
    default     = var.compute_instances_with_low_utilization_default_action
    enum        = local.compute_instances_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_with_low_utilization_enabled_actions
    enum        = local.compute_instances_with_low_utilization_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_instances_with_low_utilization_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_compute_instances_with_low_utilization
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

pipeline "correct_compute_instances_with_low_utilization" {
  title         = "Correct Compute instances with low utilization"
  description   = "Corrects Compute instances with low utilization based on the chosen action."
  documentation = file("./pipelines/compute/docs/correct_compute_instances_with_low_utilization.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      instance_name = string
      project       = string
      zone          = string
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_instances_with_low_utilization_default_action
    enum        = local.compute_instances_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_with_low_utilization_enabled_actions
    enum        = local.compute_instances_with_low_utilization_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Compute instances without graviton processor."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.instance_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_compute_instance_with_low_utilization
    args = {
      instance_name      = each.value.instance_name
      project            = each.value.project
      zone               = each.value.zone
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

pipeline "correct_one_compute_instance_with_low_utilization" {
  title         = "Correct one Compute instance with low utilization"
  description   = "Runs corrective action on a single Compute instance with low utilization."
  documentation = file("./pipelines/compute/docs/correct_one_compute_instance_with_low_utilization.md")
  tags          = merge(local.compute_common_tags, { class = "unused" })

  param "instance_name" {
    type        = string
    description = "The name of the Compute instance."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "machine_type" {
    type        = string
    description = "The machine type to downgrade to."
    default     = var.machine_type
  }

  param "zone" {
    type        = string
    description = local.description_zone
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.compute_instances_with_low_utilization_default_action
    enum        = local.compute_instances_with_low_utilization_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.compute_instances_with_low_utilization_enabled_actions
    enum        = local.compute_instances_with_low_utilization_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Compute instance ${param.instance_name} in project ${param.project} zone ${param.zone} has low utilization."
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
            text     = "Skipped Compute instance ${param.title} with low utilization."
          }
          success_msg = "Skipping Compute instance ${param.title}."
          error_msg   = "Error skipping Compute instance ${param.title}."
        },
        "stop_downgrade_instance_type" = {
          label        = "Stop & Downgrade Instance Type"
          value        = "stop_downgrade_instance_type"
          style        = local.style_alert
          pipeline_ref = pipeline.stop_downgrade_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            project_id    = param.project
            machine_type  = param.machine_type
            zone          = param.zone
            conn          = param.conn
          }
          success_msg = "Stopped Compute instance ${param.title} and downgraded instance type."
          error_msg   = "Error stopping Compute instance ${param.title} and downgrading instance type."
        },
        "stop_instance" = {
          label        = "Stop Instance"
          value        = "stop_instance"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.stop_compute_instance
          pipeline_args = {
            instance_name = param.instance_name
            project_id    = param.project
            zone          = param.zone
            conn          = param.conn
          }
          success_msg = "Stopped Compute instance ${param.title}."
          error_msg   = "Error stopping Compute instance ${param.title}."
        }
      }
    }
  }
}

pipeline "stop_downgrade_compute_instance" {
  title       = "Stop & downgrade Compute instance"
  description = "Stops a Compute instance and downgrades its instance type."

  param "instance_name" {
    type        = string
    description = "The name of the Compute instance."
  }

  param "machine_type" {
    type        = string
    description = "The machine type to downgrade to."
  }

  param "project_id" {
    type        = string
    description = local.description_project
  }

  param "zone" {
    type        = string
    description = local.description_zone
  }

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  step "pipeline" "stop_compute_instance" {
    pipeline = gcp.pipeline.stop_compute_instance
    args = {
      instance_name = param.instance_name
      project_id    = param.project_id
      zone          = param.zone
      conn          = param.conn
    }
  }

  step "pipeline" "downgrade_instance_type" {
    depends_on = [step.pipeline.stop_compute_instance]
    pipeline   = gcp.pipeline.set_compute_instance_machine_type
    args = {
      instance_name = param.instance_name
      machine_type  = param.machine_type
      project_id    = param.project_id
      zone          = param.zone
      conn          = param.conn
    }
  }

  step "pipeline" "start_compute_instance" {
    depends_on = [step.pipeline.downgrade_instance_type]
    pipeline   = gcp.pipeline.start_compute_instance
    args = {
      instance_name = param.instance_name
      project_id    = param.project_id
      zone          = param.zone
      conn          = param.conn
    }
  }
}
