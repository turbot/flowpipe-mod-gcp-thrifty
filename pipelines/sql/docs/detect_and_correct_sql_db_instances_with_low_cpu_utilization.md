# Detect & correct SQL DB instances with low CPU utilization

## Overview

SQL instances can be costly to run, especially if they're rarely used, instances with low average CPU utilization should be reviewed to determine if they're still required.

This pipeline detects SQL instances with low average daily CPU utilization and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

This control will work out-of-the-box with some sensible defaults (configurable via [variables](https://flowpipe.io/docs/build/mod-variables)).

You should be able to simply run the following command in your terminal:
```sh
flowpipe pipeline run detect_and_correct_sql_db_instances_with_low_cpu_utilization
```

By default, Flowpipe runs in [wizard](https://hub.flowpipe.io/mods/turbot/gcp_thrifty#wizard) mode and prompts directly in the terminal for a decision on the action(s) to take for each detected resource.

However, you can run Flowpipe in [server](https://flowpipe.io/docs/run/server) mode with [external integrations](https://flowpipe.io/docs/build/input#create-an-integration), allowing it to prompt for input via `http`, `slack`, `teams`, etc.

Alternatively, you can choose to configure and run in other modes:
* [Notify](https://hub.flowpipe.io/mods/turbot/gcp_thrifty#notify): Provides detections without taking any corrective action.
* [Automatic](https://hub.flowpipe.io/mods/turbot/gcp_thrifty#automatic): Performs corrective actions automatically without user intervention.