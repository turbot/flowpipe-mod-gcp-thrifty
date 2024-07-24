# Detect & correct AlloyDB clusters exceeding max age

## Overview

AlloyDB clusters can be costly to run, especially if they're rarely used, clusters exceeding a certain age should be reviewed to determine if they're still required.

This pipeline detects AlloyDB clusters exceeding a certain age and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)
- `alloydb_clusters_exceeding_max_age_trigger_enabled` should be set to `true` as the default is `false`.
- `alloydb_clusters_exceeding_max_age_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `alloydb_clusters_exceeding_max_age_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_alloydb_cluster"` to delete the cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```