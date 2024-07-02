# Correct one Logging bucket with high retention

Logging buckets can be costly to run, especially if they're rarely used, buckets with high retention periods should be reviewed to determine if they're still required.

This pipeline allows you to specify a single instance and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_logging_buckets_with_high_retention_pipeline pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_logging_buckets_with_high_retention_pipeline).