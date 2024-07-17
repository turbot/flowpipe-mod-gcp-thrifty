# Correct one Compute disk exceeding max size

## Overview

Excessively large compute disks accrue high costs and usually aren't required to be so large, these should be reviewed and if not required removed.

This pipeline allows you to specify a single compute disk and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_exceeding_max_size pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_disks_exceeding_max_size).