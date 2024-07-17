# Correct one Kubernetes cluster exceeding max age

Kubernetes clusters can be expensive to run, especially when they are not being used.

This pipeline corrects a single Kubernetes cluster that has exceeded a certain age by either sending a notification or attempting to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_kubernetes_clusters_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_kubernetes_clusters_exceeding_max_age).