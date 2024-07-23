locals {
  kubernetes_clusters_vertical_pod_autoscaling_disabled_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name,
      location,
      _ctx ->> 'connection_name' as cred,
      project
    from
      gcp_kubernetes_cluster
    where
      not (vertical_pod_autoscaling -> 'enabled')::bool
  EOQ
}

trigger "query" "detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled" {
  title         = "Detect & correct GKE clusters without vertical pod autoscaling"
  description   = "Identifies GKE clusters without vertical pod autoscaling enabled and executes the chosen action."
  documentation = file("./pipelines/kubernetes/docs/detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  enabled  = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_enabled
  schedule = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_schedule
  database = var.database
  sql      = local.kubernetes_clusters_vertical_pod_autoscaling_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_kubernetes_clusters_vertical_pod_autoscaling_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled" {
  title         = "Detect & correct GKE clusters without vertical pod autoscaling"
  description   = "Detects GKE clusters without vertical pod autoscaling enabled and runs your chosen action."
  documentation = file("./pipelines/kubernetes/docs/detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused", type = "featured" })

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
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.kubernetes_clusters_vertical_pod_autoscaling_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_kubernetes_clusters_vertical_pod_autoscaling_disabled
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

pipeline "correct_kubernetes_clusters_vertical_pod_autoscaling_disabled" {
  title         = "Correct GKE clusters without vertical pod autoscaling"
  description   = "Executes corrective actions on GKE clusters without vertical pod autoscaling enabled."
  documentation = file("./pipelines/kubernetes/docs/correct_kubernetes_clusters_vertical_pod_autoscaling_disabled_pipeline.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title    = string
      name     = string
      location = string
      project  = string
      cred     = string
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
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} GKE clusters without vertical pod autoscaling."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_kubernetes_cluster_vertical_pod_autoscaling_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      location           = each.value.location
      project            = each.value.project
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_kubernetes_cluster_vertical_pod_autoscaling_disabled" {
  title         = "Correct one GKE cluster without vertical pod autoscaling"
  description   = "Runs corrective action on a single GKE cluster without vertical pod autoscaling enabled."
  documentation = file("./pipelines/kubernetes/docs/correct_one_kubernetes_cluster_vertical_pod_autoscaling_disabled_pipeline.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the GKE cluster."
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
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_vertical_pod_autoscaling_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected GKE cluster ${param.title} without vertical pod autoscaling."
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
            text     = "Skipped GKE cluster ${param.title} without vertical pod autoscaling."
          }
          success_msg = "Skipped GKE cluster ${param.title}."
          error_msg   = "Error skipping GKE cluster ${param.title}."
        },
        "delete_kubernetes_cluster" = {
          label        = "Delete GKE Cluster"
          value        = "delete_kubernetes_cluster"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_kubernetes_cluster
          pipeline_args = {
            cluster_name = param.name
            cred         = param.cred
            project_id   = param.project
            zone         = param.location
          }
          success_msg = "Deleted GKE cluster ${param.title}."
          error_msg   = "Error deleting GKE cluster ${param.title}."
        }
      }
    }
  }
}

variable "kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "kubernetes_clusters_vertical_pod_autoscaling_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "kubernetes_clusters_vertical_pod_autoscaling_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_kubernetes_cluster"]
}
