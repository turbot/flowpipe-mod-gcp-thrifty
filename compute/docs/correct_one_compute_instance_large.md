# Correct one Compute instance if large

## Overview

Compute instances can be quite costly to retain, it is also likely that after a certain point in time they're no longer required and should be cleaned up to prevent further costs. Large compute instances are unusual, expensive and should be reviewed.

This pipeline allows you to specify a single large compute instance and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_instances_large pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_instances_large).