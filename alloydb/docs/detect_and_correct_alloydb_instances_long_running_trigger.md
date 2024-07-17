# Detect & correct AlloyDB instances exceeding max age

## Overview

AlloyDB instances can be costly to run, especially if they're rarely used, instances exceeding a certain age should be reviewed to determine if they're still required.

This trigger detects AlloyDB instances exceeding a certain age and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `alloydb_instances_long_running_trigger_enabled` should be set to `true` as the default is `false`.
- `alloydb_instances_long_running_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `alloydb_instances_long_running_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_alloydb_instance"` to delete the bucket).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```