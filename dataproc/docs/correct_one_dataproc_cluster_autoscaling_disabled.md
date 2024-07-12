# Correct one Dataproc cluster with autoscaling disabled

Dataproc clusters can be costly to run, especially if they're not being used to their full potential. Clusters with autoscaling disabled should be reviewed to determine if they're still required.

This pipeline allows you to specify a single cluster and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_dataproc_clusters_autoscaling_disabled pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_dataproc_clusters_autoscaling_disabled).