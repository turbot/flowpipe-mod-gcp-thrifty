// locals {
//   storage_bucket_without_lifecycle_policy_query = <<-EOQ
//   select
//     name,
//     project
//   from
//     gcp_storage_bucket
//   where
//     lifecycle_rules is null
//     and name = 'bucket-for-test-mr';
//   EOQ
// }

// trigger "query" "detect_and_correct_storage_bucket_without_lifecycle_policy" {
//   title       = "Detect & correct Storage buckets without lifecycle policy"
//   description = "Detects Storage buckets which do not have a lifecycle policy and runs your chosen action."
//   // documentation = file("./storage/docs/detect_and_correct_storage_bucket_without_lifecycle_policy_trigger.md")
//   tags = merge(local.storage_common_tags, { class = "managed" })

//   enabled  = var.storage_bucket_without_lifecycle_policy_trigger_enabled
//   schedule = var.storage_bucket_without_lifecycle_policy_trigger_schedule
//   database = var.database
//   sql      = local.storage_bucket_without_lifecycle_policy_query

//   capture "insert" {
//     pipeline = pipeline.correct_storage_bucket_without_lifecycle_policy
//     args = {
//       items = self.inserted_rows
//     }
//   }
// }

// pipeline "detect_and_correct_storage_bucket_without_lifecycle_policy" {
//   title       = "Detect & correct Storage buckets without lifecycle policy"
//   description = "Detects Storage buckets which do not have a lifecycle policy and runs your chosen action."
//   // documentation = file("./storage/docs/detect_and_correct_storage_bucket_without_lifecycle_policy.md")
//   tags = merge(local.storage_common_tags, { class = "managed", type = "featured" })

//   param "database" {
//     type        = string
//     description = local.description_database
//     default     = var.database
//   }

//   param "policy" {
//     type        = string
//     description = "Lifecycle policy to apply to the Storage bucket, if 'apply' is the chosen response."
//     default     = var.storage_bucket_without_lifecycle_policy_default_policy
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.storage_bucket_without_lifecycle_policy_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.storage_bucket_without_lifecycle_policy_enabled_actions
//   }

//   step "query" "detect" {
//     database = param.database
//     sql      = local.storage_bucket_without_lifecycle_policy_query
//   }

//   step "pipeline" "respond" {
//     pipeline = pipeline.correct_storage_bucket_without_lifecycle_policy
//     args = {
//       items              = step.query.detect.rows
//       policy             = param.policy
//       notifier           = param.notifier
//       notification_level = param.notification_level
//       approvers          = param.approvers
//       default_action     = param.default_action
//       enabled_actions    = param.enabled_actions
//     }
//   }
// }

// pipeline "correct_storage_bucket_without_lifecycle_policy" {
//   title       = "Correct Storage buckets without lifecycle policy"
//   description = "Runs corrective action on a collection of Storage buckets which do not have a lifecycle policy."
//   // documentation = file("./storage/docs/correct_storage_bucket_without_lifecycle_policy.md")
//   tags = merge(local.storage_common_tags, { class = "managed" })

//   param "items" {
//     type = list(object({
//       name    = string
//       project = string
//     }))
//   }

//   param "policy" {
//     type        = string
//     description = "Lifecycle policy to apply to the Storage bucket, if 'apply' is the chosen response."
//     default     = var.storage_bucket_without_lifecycle_policy_default_policy
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.storage_bucket_without_lifecycle_policy_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.storage_bucket_without_lifecycle_policy_enabled_actions
//   }

//   step "message" "notify_detection_count" {
//     if       = var.notification_level == local.level_verbose
//     notifier = notifier[param.notifier]
//     text     = "Detected ${length(param.items)} Storage Buckets without a lifecycle policy."
//   }

//   step "transform" "items_by_id" {
//     value = { for row in param.items : row.name => row }
//   }

//   step "pipeline" "correct_item" {
//     for_each        = step.transform.items_by_id.value
//     max_concurrency = var.max_concurrency
//     pipeline        = pipeline.correct_one_storage_bucket_without_lifecycle_policy
//     args = {
//       name               = each.value.name
//       project            = each.value.project
//       policy             = param.policy
//       notifier           = param.notifier
//       notification_level = param.notification_level
//       approvers          = param.approvers
//       default_action     = param.default_action
//       enabled_actions    = param.enabled_actions
//     }
//   }
// }

// pipeline "correct_one_storage_bucket_without_lifecycle_policy" {
//   title       = "Correct one Storage bucket without lifecycle policy"
//   description = "Runs corrective action on an individual Storage bucket which does not have a lifecycle policy."
//   // documentation = file("./storage/docs/correct_one_storage_bucket_without_lifecycle_policy.md")
//   tags = merge(local.storage_common_tags, { class = "managed" })

//   param "name" {
//     type        = string
//     description = "Name of the Storage Bucket."
//   }

//   param "project" {
//     type        = string
//     description = "The project of the Compute Disk."
//   }

//   param "policy" {
//     type        = string
//     description = "Lifecycle policy to apply to the Storage Bucket."
//     default     = var.storage_bucket_without_lifecycle_policy_default_policy
//   }

//   param "cred" {
//     type        = string
//     description = local.description_credential
//     default     = "default"
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.storage_bucket_without_lifecycle_policy_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.storage_bucket_without_lifecycle_policy_enabled_actions
//   }

//   step "pipeline" "respond" {
//     pipeline = detect_correct.pipeline.correction_handler
//     args = {
//       notifier           = param.notifier
//       notification_level = param.notification_level
//       approvers          = param.approvers
//       detect_msg         = "Detected Storage Bucket ${param.name} without a lifecycle policy."
//       default_action     = param.default_action
//       enabled_actions    = param.enabled_actions
//       actions = {
//         "skip" = {
//           label        = "Skip"
//           value        = "skip"
//           style        = local.style_info
//           pipeline_ref = local.pipeline_optional_message
//           pipeline_args = {
//             notifier = param.notifier
//             send     = param.notification_level == local.level_verbose
//             text     = "Skipped Storage Bucket ${param.name} without a lifecycle policy."
//           }
//           success_msg = ""
//           error_msg   = ""
//         }
//         "apply_policy" = {
//           label        = "Apply Policy"
//           value        = "apply_policy"
//           style        = local.style_ok
//           pipeline_ref = local.gcp_pipeline_update_storage_bucket
//           pipeline_args = {
//             bucket_name      = param.name
//             cred             = param.cred
//             project_id       = param.project
//             lifecycle_policy = param.policy
//           }
//           success_msg = "Applied lifecycle policy to Storage Bucket ${param.name}."
//           error_msg   = "Error applying lifecycle policy to Storage Bucket ${param.name}."
//         }
//       }
//     }
//   }
// }

// variable "storage_bucket_without_lifecycle_policy_trigger_enabled" {
//   type        = bool
//   default     = false
//   description = "If true, the trigger is enabled."
// }

// variable "storage_bucket_without_lifecycle_policy_trigger_schedule" {
//   type        = string
//   default     = "15m"
//   description = "The schedule on which to run the trigger if enabled."
// }

// variable "storage_bucket_without_lifecycle_policy_default_action" {
//   type        = string
//   description = "The default action to use for the detected item, used if no input is provided."
//   default     = "apply_policy"
// }

// variable "storage_bucket_without_lifecycle_policy_enabled_actions" {
//   type        = list(string)
//   description = "The list of enabled actions to provide to approvers for selection."
//   default     = ["skip", "apply_policy"]
// }

// variable "storage_bucket_without_lifecycle_policy_default_policy" {
//   type        = string
//   description = "The default Storage bucket lifecycle policy to apply"
//   default     = "{ \"rule\": [ { \"action\": { \"type\": \"Delete\" }, \"condition\": { \"age\": 365 } } ] }"
// }
