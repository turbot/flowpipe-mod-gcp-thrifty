# Correct compute disk attached to stopped instances

## Overview

Compute disk attached to stopped instances still incur costs even though they may not be used; these should be reviewed and either detached from the stopped instance or deleted.

This pipeline allows you to specify a single compute disk and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disks_attached_to_stopped_instance_pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_disks_attached_to_stopped_instance).