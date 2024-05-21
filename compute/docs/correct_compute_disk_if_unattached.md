# Correct compute disks if unattached

## Overview

Compute disks which are not attached will still incur charges and provide no real use, these disks should be reviewed and if necessary tidied up.

This pipeline allows you to specify a collection of unattached compute disks and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_disk_if_unattached_trigger pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_disk_if_unattached_trigger)
- [detect_and_correct_compute_disk_if_unattached_trigger trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_disk_if_unattached_trigger)