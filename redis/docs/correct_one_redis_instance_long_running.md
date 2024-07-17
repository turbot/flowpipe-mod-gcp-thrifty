# Correct one Redis instance exceeding a threshold

Redis instances can be costly to run, especially if they're rarely used, instances that have been running for a long time should be reviewed to determine if they're still required.

This pipeline allows you to specify a single Redis instance and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_redis_instances_long_running pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_redis_instances_long_running).