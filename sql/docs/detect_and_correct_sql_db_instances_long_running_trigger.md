# Detect & correct SQL DB instances exceeding a long running threshold

## Overview

SQL DB instances can be costly to run, especially if they're rarely used, instances that have been running for a long time should be reviewed to determine if they're still required.

This trigger allows you to specify a threshold for how long an instance has been running and then either send a notification or attempt to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `sql_db_instances_long_running_trigger_enabled` should be set to `true` as the default is `false`.
- `sql_db_instances_long_running_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `sql_db_instances_long_running_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_sql_db_instance"` to delete the SQL DB instance).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```