# Correct Dataproc cluster without autoscaling

## Overview

Dataproc clusters can be costly to run, especially if they're not being used to their full potential. Clusters with autoscaling disabled should be reviewed to determine if they're still required.

This pipeline allows you to specify a single cluster and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_dataproc_clusters_without_autoscaling pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_dataproc_clusters_without_autoscaling)
- [detect_and_correct_dataproc_clusters_without_autoscaling trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_dataproc_clusters_without_autoscaling)