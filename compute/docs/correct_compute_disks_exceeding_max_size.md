# Correct compute disks exceeding max size

## Overview

Excessively large compute disks accrue high costs and usually aren't required to be so large, these should be reviewed and if not required removed.

This pipeline allows you to specify a collection of compute disks and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_disks_exceeding_max_size_trigger pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_disks_exceeding_max_size_trigger)
- [detect_and_correct_compute_disks_exceeding_max_size_trigger trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_disks_exceeding_max_size_trigger)