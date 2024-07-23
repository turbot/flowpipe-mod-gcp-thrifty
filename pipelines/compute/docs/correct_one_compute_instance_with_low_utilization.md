# Correct one compute instance with low utilization

## Overview

Compute instance with low utilization usage may be indicative that they're no longer required, these should be reviewed.

This pipeline allows you to specify a single compute instance with low utilization usage and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_instances_with_low_utilization pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_instances_with_low_utilization).