locals {
  compute_target_vpn_gateways_no_tunnels_query = <<-EOQ
    select
      concat(name, ' [', location, '/', project, ']') as title,
      name,
      project,
      sp_connection_name as conn,
      location
    from
      gcp_compute_target_vpn_gateway
    where
      tunnels is null;
  EOQ

  vpn_gateways_with_no_tunnels_enabled_actions = ["skip", "delete_vpn_gateway"]
  vpn_gateways_with_no_tunnels_default_action  = ["notify", "skip", "delete_vpn_gateway"]
}

variable "vpn_gateways_with_no_tunnels_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
  tags = {
    folder = "Advanced/Network"
  }
}

variable "vpn_gateways_with_no_tunnels_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
  tags = {
    folder = "Advanced/Network"
  }
}

variable "vpn_gateways_with_no_tunnels_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
  enum        = ["notify", "skip", "delete_vpn_gateway"]

  tags = {
    folder = "Advanced/Network"
  }
}

variable "vpn_gateways_with_no_tunnels_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "delete_vpn_gateway"]
  enum        = ["skip", "delete_vpn_gateway"]

  tags = {
    folder = "Advanced/Network"
  }
}

trigger "query" "detect_and_correct_vpn_gateways_with_no_tunnels" {
  title         = "Detect & correct VPN gateways with no tunnels"
  description   = "Detect VPN gateways with no tunnels attached and run your chosen action."
  documentation = file("./pipelines/network/docs/detect_and_correct_vpn_gateways_with_no_tunnels_trigger.md")
  tags          = merge(local.network_common_tags, { class = "unused" })

  enabled  = var.vpn_gateways_with_no_tunnels_trigger_enabled
  schedule = var.vpn_gateways_with_no_tunnels_trigger_schedule
  database = var.database
  sql      = local.compute_target_vpn_gateways_no_tunnels_query

  capture "insert" {
    pipeline = pipeline.correct_vpn_gateways_with_no_tunnels
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpn_gateways_with_no_tunnels" {
  title         = "Detect & correct VPN gateways with no tunnels"
  description   = "Detect VPN gateways with no tunnels attached and run your chosen action."
  documentation = file("./pipelines/network/docs/detect_and_correct_vpn_gateways_with_no_tunnels.md")
  tags          = merge(local.network_common_tags, { class = "unused", recommended = "true" })

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
    default     = var.vpn_gateways_with_no_tunnels_default_action
    enum        = local.vpn_gateways_with_no_tunnels_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpn_gateways_with_no_tunnels_enabled_actions
    enum        = local.vpn_gateways_with_no_tunnels_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.compute_target_vpn_gateways_no_tunnels_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpn_gateways_with_no_tunnels
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

pipeline "correct_vpn_gateways_with_no_tunnels" {
  title         = "Correct VPN gateways with no tunnels"
  description   = "Runs corrective action on VPN gateways with no tunnels attached."
  documentation = file("./pipelines/network/docs/correct_vpn_gateways_with_no_tunnels.md")
  tags          = merge(local.network_common_tags, { class = "unused", folder = "Internal" })

  param "items" {
    type = list(object({
      title    = string
      name     = string
      project  = string
      location = string
      conn     = string
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
    default     = var.vpn_gateways_with_no_tunnels_default_action
    enum        = local.vpn_gateways_with_no_tunnels_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpn_gateways_with_no_tunnels_enabled_actions
    enum        = local.vpn_gateways_with_no_tunnels_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} VPN gateways with no tunnels attached."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpn_gateway_with_no_tunnels
    args = {
      title              = each.value.title
      name               = each.value.name
      project            = each.value.project
      location           = each.value.location
      conn               = connection.gcp[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_vpn_gateway_with_no_tunnels" {
  title         = "Correct one VPN gateway with no tunnels"
  description   = "Runs corrective action on a VPN gateway with no tunnels attached."
  documentation = file("./pipelines/network/docs/correct_one_vpn_gateway_with_no_tunnels.md")
  tags          = merge(local.network_common_tags, { class = "unused", folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "project" {
    type        = string
    description = local.description_project
  }

  param "name" {
    type        = string
    description = "The name of the VPN gateway."
  }

  param "location" {
    type        = string
    description = local.description_location
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
    default     = var.vpn_gateways_with_no_tunnels_default_action
    enum        = local.vpn_gateways_with_no_tunnels_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpn_gateways_with_no_tunnels_enabled_actions
    enum        = local.vpn_gateways_with_no_tunnels_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPN gateway ${param.title} with no tunnels attached."
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
            text     = "Skipped deletion of VPN gateway ${param.title} with no tunnels attached."
          }
          success_msg = "Skipped deletion of VPN gateway ${param.title}."
          error_msg   = "Failed to skip deletion of VPN gateway ${param.title}."
        },
        "delete_vpn_gateway" = {
          label        = "Delete VPN Gateway"
          value        = "delete_vpn_gateway"
          style        = local.style_alert
          pipeline_ref = gcp.pipeline.delete_vpn_gateway
          pipeline_args = {
            conn             = param.conn
            vpn_gateway_name = param.name
            project_id       = param.project
            region           = param.location
          }
          success_msg = "Deleted VPN gateway ${param.title}."
          error_msg   = "Failed to delete VPN gateway ${param.title}."
        }
      }
    }
  }
}
