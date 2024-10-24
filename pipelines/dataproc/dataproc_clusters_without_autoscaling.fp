locals {
  dataproc_clusters_without_autoscaling_query = <<-EOQ
  select
    concat(cluster_name, ' [', location, '/', project, ']') as title,
    cluster_name as name,
    sp_connection_name as conn,
    location,
    project
  from
    gcp_dataproc_cluster
  where
    config -> 'autoscalingConfig' -> 'policyUri' is null
  EOQ

  dataproc_clusters_without_autoscaling_default_action  = ["notify", "skip", "delete_dataproc_cluster"]
  dataproc_clusters_without_autoscaling_enabled_actions = ["skip", "delete_dataproc_cluster"]
}

variable "dataproc_clusters_without_autoscaling_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Dataproc"
  }
}

variable "dataproc_clusters_without_autoscaling_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Dataproc"
  }
}

variable "dataproc_clusters_without_autoscaling_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_dataproc_cluster"]

  tags = {
    folder = "Advanced/Dataproc"
  }
}

variable "dataproc_clusters_without_autoscaling_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_dataproc_cluster"]
  enum        = ["skip", "delete_dataproc_cluster"]

  tags = {
    folder = "Advanced/Dataproc"
  }
}

trigger "query" "detect_and_correct_dataproc_clusters_without_autoscaling" {
  title         = "Detect & correct Dataproc clusters without autoscaling"
  description   = "Identifies Dataproc clusters without autoscaling and executes the chosen action."
  documentation = file("./pipelines/dataproc/docs/detect_and_correct_dataproc_clusters_without_autoscaling_trigger.md")
  tags          = merge(local.dataproc_common_tags, { class = "unused" })

  enabled  = var.dataproc_clusters_without_autoscaling_trigger_enabled
  schedule = var.dataproc_clusters_without_autoscaling_trigger_schedule
  database = var.database
  sql      = local.dataproc_clusters_without_autoscaling_query

  capture "insert" {
    pipeline = pipeline.correct_dataproc_clusters_without_autoscaling
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_dataproc_clusters_without_autoscaling" {
  title         = "Detect & correct Dataproc clusters without autoscaling"
  description   = "Detects Dataproc clusters without autoscaling enabled and runs your chosen action."
  documentation = file("./pipelines/dataproc/docs/detect_and_correct_dataproc_clusters_without_autoscaling.md")
  tags          = merge(local.dataproc_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.dataproc_clusters_without_autoscaling_default_action
    enum        = local.dataproc_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dataproc_clusters_without_autoscaling_enabled_actions
    enum        = local.dataproc_clusters_without_autoscaling_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.dataproc_clusters_without_autoscaling_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_dataproc_clusters_without_autoscaling
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

pipeline "correct_dataproc_clusters_without_autoscaling" {
  title         = "Correct Dataproc clusters without autoscaling"
  description   = "Executes corrective actions on Dataproc clusters without autoscaling enabled."
  documentation = file("./pipelines/dataproc/docs/correct_dataproc_clusters_without_autoscaling.md")
  tags          = merge(local.dataproc_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      title    = string
      conn     = string
      name     = string
      location = string
      project  = string
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
    default     = var.dataproc_clusters_without_autoscaling_default_action
    enum        = local.dataproc_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dataproc_clusters_without_autoscaling_enabled_actions
    enum        = local.dataproc_clusters_without_autoscaling_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} Dataproc clusters without autoscaling."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_dataproc_cluster_without_autoscaling
    args = {
      title              = each.value.title
      name               = each.value.name
      conn               = connection.gcp[each.value.conn]
      location           = each.value.location
      project            = each.value.project
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_dataproc_cluster_without_autoscaling" {
  title         = "Correct one Dataproc clusters without autoscaling"
  description   = "Runs corrective action on a single Dataproc cluster without autoscaling enabled."
  documentation = file("./pipelines/dataproc/docs/correct_one_dataproc_cluster_without_autoscaling.md")
  tags          = merge(local.dataproc_common_tags, { class = "unused", folder = "Internal" })

  param "conn" {
    type        = connection.gcp
    description = local.description_connection
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Dataproc cluster."
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
    default     = var.dataproc_clusters_without_autoscaling_default_action
    enum        = local.dataproc_clusters_without_autoscaling_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dataproc_clusters_without_autoscaling_enabled_actions
    enum        = local.dataproc_clusters_without_autoscaling_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Dataproc cluster ${param.title} without autoscaling."
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
            text     = "Skipped Dataproc cluster ${param.title} without autoscaling."
          }
          success_msg = "Skipped Dataproc cluster ${param.title}."
          error_msg   = "Error skipping Dataproc cluster ${param.title}."
        },
        "delete_dataproc_cluster" = {
          label        = "Delete Dataproc Cluster"
          value        = "delete_dataproc_cluster"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_dataproc_cluster
          pipeline_args = {
            cluster_name = param.name
            conn         = param.conn
            project_id   = param.project
            region       = param.location
          }
          success_msg = "Deleted Dataproc cluster ${param.title}."
          error_msg   = "Error deleting Dataproc cluster ${param.title}."
        }
      }
    }
  }
}
