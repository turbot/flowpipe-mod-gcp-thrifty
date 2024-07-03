// Tags
locals {
  gcp_thrifty_common_tags = {
    category = "Cost"
    plugin   = "gcp"
    service  = "GCP"
  }
}

// Consts
locals {
  level_verbose = "verbose"
  level_info    = "info"
  level_error   = "error"
  style_ok      = "ok"
  style_info    = "info"
  style_alert   = "alert"
}

// Common Texts
locals {
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_project          = "GCP Project ID of the resource(s)."
  description_location         = "GCP Location of the resource(s)."
  description_zone             = "GCP Zone of the resource(s)."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}

// Pipeline References
locals {
  pipeline_optional_message               = detect_correct.pipeline.optional_message
  gcp_pipeline_delete_compute_snapshot    = gcp.pipeline.delete_compute_snapshot
  gcp_pipeline_create_compute_snapshot    = gcp.pipeline.create_compute_snapshot
  gcp_pipeline_delete_compute_disk        = gcp.pipeline.delete_compute_disk
  gcp_pipeline_detach_compute_disk        = gcp.pipeline.detach_compute_disk_from_instance
  gcp_pipeline_start_compute_instance     = gcp.pipeline.start_compute_instance
  gcp_pipeline_stop_compute_instance      = gcp.pipeline.stop_compute_instance
  gcp_pipeline_terminate_compute_instance = gcp.pipeline.delete_compute_instance
  gcp_pipeline_delete_compute_address     = gcp.pipeline.delete_compute_address
  gcp_pipeline_delete_sql_instance        = gcp.pipeline.delete_sql_instance
  gcp_pipeline_stop_sql_instance          = gcp.pipeline.stop_sql_instance
  gcp_pipeline_update_logging_bucket      = gcp.pipeline.update_logging_bucket
  gcp_pipeline_update_storage_bucket      = gcp.pipeline.update_storage_bucket
  gcp_pipeline_set_machine_type           = gcp.pipeline.set_machine_type
  gcp_pipeline_update_node_group          = gcp.pipeline.update_node_group
  gcp_pipeline_delete_vpn_gateway         = gcp.pipeline.delete_vpn_gateway
}