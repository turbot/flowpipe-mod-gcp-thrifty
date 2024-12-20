# Detect & correct large Compute instances

## Overview

Compute instances can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs. Large Compute instances are unusual, expensive and should be reviewed.

This query trigger detects large Compute instances and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `compute_instances_large_trigger_enabled` should be set to `true` as the default is `false`.
- `compute_instances_large_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `compute_instances_large_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"terminate_instance"` to delete the instance).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```