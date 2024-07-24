# Detect & correct Logging buckets with high retention

## Overview

Logging buckets can be costly to run, especially if they're rarely used, buckets with high retention periods should be reviewed to determine if they're still required.

This query trigger detects Logging buckets with high retention periods and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `logging_buckets_with_high_retention_trigger_enabled` should be set to `true` as the default is `false`.
- `logging_buckets_with_high_retention_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `logging_buckets_with_high_retention_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"update_retention"` to update the retention period of the bucket).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```