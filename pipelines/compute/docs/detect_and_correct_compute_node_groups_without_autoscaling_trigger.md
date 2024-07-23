# Detect & correct Compute node group without autoscaling

## Overview

Compute node groups can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This query trigger detects compute node groups that have autoscaling disabled and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_node_groups_without_autoscaling_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_node_groups_without_autoscaling_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_node_groups_without_autoscaling_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"enable_autoscaling_policy"` to enable autoscaling policy).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```