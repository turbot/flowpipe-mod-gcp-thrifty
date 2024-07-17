# Correct Compute disk attached to stopped instances

## Overview

Compute disk attached to stopped instances still incur costs even though they may not be used; these should be reviewed and either detached from the stopped instance or deleted.

This pipeline allows you to specify a collection of compute disk and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_disks_attached_to_stopped_instances pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_disks_attached_to_stopped_instance)
- [detect_and_correct_compute_disks_attached_to_stopped_instances trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_disks_attached_to_stopped_instance)