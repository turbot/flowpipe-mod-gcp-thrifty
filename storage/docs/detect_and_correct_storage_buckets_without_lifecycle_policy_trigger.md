# Detect & correct Storage buckets without lifecycle policy

## Overview

Storage buckets can be costly to run, especially if they're rarely used, buckets without a lifecycle policy should be reviewed to determine if they're still required.

This pipeline detects storage buckets without a lifecycle policy and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configred by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `storage_buckets_without_lifecycle_policy_trigger_enabled` should be set to `true` as the default is `false`.
- `storage_buckets_without_lifecycle_policy_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `storage_buckets_without_lifecycle_policy_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_bucket"` to delete the bucket).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```