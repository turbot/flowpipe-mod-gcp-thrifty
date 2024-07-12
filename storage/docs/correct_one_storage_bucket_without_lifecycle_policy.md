# Correct one Storage bucket without lifecycle policy

Storage buckets can be costly to run, especially if they're rarely used, buckets without lifecycle policies should be reviewed to determine if they're still required.

This pipeline allows you to specify a single bucket and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_storage_buckets_without_lifecycle_policy pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_storage_buckets_without_lifecycle_policy).