# Detect & correct compute instances with low utilization

## Overview

Compute instances with low utilization may be indicative that they're no longer required, these should be reviewed.

This query trigger detects compute instances with low average usage and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_instances_with_low_utilization_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_instances_with_low_utilization_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_instances_with_low_utilization_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"stop_instance"` to stop instance or `"stop_downgrade_instance_type"` to stop and downgrade instance type).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```