# Correct Compute instances with low utilization

## Overview

Compute instances with low utilization may be indicative that they're no longer required, these should be reviewed.

This pipeline allows you to specify a collection of compute instances with low utilization and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_instances_with_low_utilization pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_instances_with_low_utilization)
- [detect_and_correct_compute_instances_with_low_utilization trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_instances_with_low_utilization)