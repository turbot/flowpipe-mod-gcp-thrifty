# Correct Compute node groups without autoscaling

## Overview

Compute node groups if autoscaling disabled can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs.

This pipeline allows you to specify a collection of Compute node groups and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_node_groups_without_autoscaling pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_node_groups_without_autoscaling)
- [detect_and_correct_compute_node_groups_without_autoscaling trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_node_groups_without_autoscaling)