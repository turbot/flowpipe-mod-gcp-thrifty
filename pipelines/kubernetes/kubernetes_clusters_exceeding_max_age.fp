locals {
  kubernetes_clusters_exceeding_max_age_query = <<-EOQ
  select
    concat(name, ' [', location, '/', project, ']') as title,
    name,
    _ctx ->> 'connection_name' as cred,
    location,
    project
  from
    gcp_kubernetes_cluster
  where
    date_part('day', now()-create_time) > ${var.kubernetes_clusters_exceeding_max_age_days};
  EOQ
}

trigger "query" "detect_and_correct_kubernetes_clusters_exceeding_max_age" {
  title         = "Detect & correct Kubernetes clusters exceeding max age"
  description   = "Detects Kubernetes clusters exceeding max age and runs your chosen action."
  documentation = file("./pipelines/kubernetes/docs/detect_and_correct_kubernetes_clusters_exceeding_max_age_trigger.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  enabled  = var.kubernetes_clusters_exceeding_max_age_trigger_enabled
  schedule = var.kubernetes_clusters_exceeding_max_age_trigger_schedule
  database = var.database
  sql      = local.kubernetes_clusters_exceeding_max_age_query

  capture "insert" {
    pipeline = pipeline.correct_kubernetes_clusters_exceeding_max_age
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_kubernetes_clusters_exceeding_max_age" {
  title         = "Detect & correct Kubernetes clusters exceeding max age"
  description   = "Detects Kubernetes clusters exceeding max age and runs your chosen action."
  documentation = file("./pipelines/kubernetes/docs/detect_and_correct_kubernetes_clusters_exceeding_max_age.md")
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
    default     = var.kubernetes_clusters_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_exceeding_max_age_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.kubernetes_clusters_exceeding_max_age_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_kubernetes_clusters_exceeding_max_age
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

pipeline "correct_kubernetes_clusters_exceeding_max_age" {
  title         = "Correct Kubernetes clusters exceeding max age"
  description   = "Runs corrective action on a collection of Kubernetes clusters exceeding max age."
  documentation = file("./pipelines/kubernetes/docs/correct_kubernetes_clusters_exceeding_max_age.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title    = string
      name     = string
      location = string
      project  = string
      cred     = string
    }))
    description = local.description_items
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
    default     = var.kubernetes_clusters_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_exceeding_max_age_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Kubernetes clusters exceeding maximum age."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_kubernetes_cluster_exceeding_max_age
    args = {
      name               = each.value.name
      project            = each.value.project
      location           = each.value.location
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

pipeline "correct_one_kubernetes_cluster_exceeding_max_age" {
  title         = "Correct one Kubernetes cluster exceeding max age"
  description   = "Runs corrective action on a Kubernetes cluster exceeding max age."
  documentation = file("./pipelines/kubernetes/docs/correct_one_kubernetes_cluster_exceeding_max_age.md")
  tags          = merge(local.kubernetes_common_tags, { class = "unused" })

  param "name" {
    type        = string
    description = "The name of the Kubernetes cluster."
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "location" {
    type        = string
    description = local.description_location
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
    default     = var.kubernetes_clusters_exceeding_max_age_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kubernetes_clusters_exceeding_max_age_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Kubernetes cluster ${param.title} exceeding maximum age."
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
            text     = "Skipped Kubernetes cluster ${param.title} exceeding maximum age."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_kubernetes_cluster" = {
          label        = "Delete Kubernetes Cluster"
          value        = "delete_kubernetes_cluster"
          style        = local.style_alert
          pipeline_ref = local.gcp_pipeline_delete_kubernetes_cluster
          pipeline_args = {
            cluster_name = param.name
            cred         = param.cred
            project_id   = param.project
            zone         = param.location
          }
          success_msg = "Deleted Kubernetes cluster ${param.title}."
          error_msg   = "Error deleting Kubernetes cluster ${param.title}."
        }
      }
    }
  }
}

variable "kubernetes_clusters_exceeding_max_age_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "kubernetes_clusters_exceeding_max_age_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "kubernetes_clusters_exceeding_max_age_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "kubernetes_clusters_exceeding_max_age_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_kubernetes_cluster"]
}

variable "kubernetes_clusters_exceeding_max_age_days" {
  type        = number
  description = "The maximum number of days Kubernetes clusters can be retained."
  default     = 15
}