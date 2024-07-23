# Correct one AlloyDB cluster exceeding max age

AlloyDB clusters can be costly to run, especially if they're rarely used, clusters exceeding a certain age should be reviewed to determine if they're still required.

This pipeline corrects one AlloyDB cluster exceeding a certain age by either sending a notification or attempting to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_alloydb_clusters_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_alloydb_clusters_exceeding_max_age).