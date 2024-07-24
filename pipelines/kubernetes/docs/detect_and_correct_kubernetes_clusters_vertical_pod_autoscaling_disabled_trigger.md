# Detect & correct Kubernetes clusters with Vertical Pod Autoscaling disabled

## Overview

Vertical Pod Autoscaling (VPA) is a feature of Kubernetes that allows the Kubernetes control plane to adjust the resource requests of a pod based on its usage. This can help to ensure that pods have the resources they need to run efficiently.

This pipeline detects Kubernetes clusters that have Vertical Pod Autoscaling disabled and then either sends a notification or attempts to perform a predefined corrective action.

## Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)

- `kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_enabled` should be set to `true` as the default is `false`.

- `kubernetes_clusters_vertical_pod_autoscaling_disabled_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)

- `kubernetes_clusters_vertical_pod_autoscaling_disabled_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_kubernetes_cluster"` to delete the kubernetes cluster).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```