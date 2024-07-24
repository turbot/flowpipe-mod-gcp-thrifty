# Detect & correct Dataprocs clusters without autoscaling

## Overview

Dataproc clusters can be costly to run, especially if they're not being used efficiently. Clusters with autoscaling disabled should be reviewed to determine if they're still required.

This pipeline detects Dataproc clusters with autoscaling disabled and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `dataproc_clusters_without_autoscaling_trigger_enabled` should be set to `true` as the default is `false`.
- `dataproc_clusters_without_autoscaling_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `dataproc_clusters_without_autoscaling_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_dataproc_cluster"` to delete the cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```