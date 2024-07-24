# Detect & correct Kubernetes clusters exceeding max age trigger

## Overview

Kubernetes clusters can be expensive to run, especially when they are not being used. This pipeline detects Kubernetes clusters that have exceeded a certain age and then either sends a notification or attempts to perform a predefined corrective action.

This pipeline detects kubernetes clusters that have exceeded a certain age and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `kubernetes_clusters_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `kubernetes_clusters_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `kubernetes_clusters_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_kubernetes_cluster"` to delete the cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```