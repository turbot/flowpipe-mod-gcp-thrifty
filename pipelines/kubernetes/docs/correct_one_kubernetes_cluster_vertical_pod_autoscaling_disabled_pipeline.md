# Correct one Kubernetes cluster with Vertical Pod Autoscaling disabled

Vertical Pod Autoscaling (VPA) is a feature of Kubernetes that allows the Kubernetes control plane to automatically adjust the resource requests and limits of containers in a pod to improve resource utilization. This can help to reduce the cost of running Kubernetes clusters by ensuring that resources are not over-provisioned.

This pipeline allows you to specify a single instance and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_one_kubernetes_cluster_vertical_pod_autoscaling_disabled_pipeline pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_one_kubernetes_cluster_vertical_pod_autoscaling_disabled_pipeline).