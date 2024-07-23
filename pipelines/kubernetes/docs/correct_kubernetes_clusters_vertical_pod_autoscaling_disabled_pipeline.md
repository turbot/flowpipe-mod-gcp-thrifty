# Correct Kubernetes clusters with Vertical Pod Autoscaling disabled

## Overview

Vertical Pod Autoscaling (VPA) is a feature of Kubernetes that allows the Kubernetes control plane to automatically adjust the resource requests and limits of containers in a pod to improve resource utilization. This can help to reduce the cost of running Kubernetes clusters by ensuring that resources are not over-provisioned.

This pipeline allows you to specify a collection of Kubernetes clusters with Vertical Pod Autoscaling disabled and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled)
- [detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_kubernetes_clusters_vertical_pod_autoscaling_disabled)
