# Correct compute disks with low usage

## Overview

Compute disks with low usage may be indicative that they're no longer required, these should be reviewed.

This pipeline allows you to specify a collection of compute disks with low usage and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_disks_with_low_usage pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_disks_with_low_usage)
- [detect_and_correct_compute_disks_with_low_usage trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_disks_with_low_usage)