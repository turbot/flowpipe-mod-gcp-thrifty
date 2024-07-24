# Detect & correct Redis instances exceeding max age 

## Overview

Redis instances can be costly to run, especially if they're rarely used, instances that have been running for a long time should be reviewed to determine if they're still required.

This trigger allows you to specify a threshold for how long an instance has been running and then either send a notification or attempt to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `redis_instances_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `redis_instances_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `redis_instances_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_redis_instance"` to delete the instance)

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```