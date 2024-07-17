# Correct one Compute disk with low usage

## Overview

Compute disks with low usage may be indicative that they're no longer required, these should be reviewed.

This pipeline allows you to specify a single compute disk with low usage and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_with_low_usage pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_disks_with_low_usage).