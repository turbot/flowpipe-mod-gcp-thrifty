# Correct Kubernetes clusters exceeding max age

## Overview

Kubernetes clusters can be expensive to run, especially when they are not being used. This pipeline detects Kubernetes clusters that have exceeded a certain age and then either sends a notification or attempts to perform a predefined corrective action.

This pipeline corrects kubernetes clusters that have exceeded a certain age by either sending a notification or attempting to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_kubernetes_clusters_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_kubernetes_clusters_exceeding_max_age)
- [detect_and_correct_kubernetes_clusters_exceeding_max_age trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_kubernetes_clusters_exceeding_max_age)