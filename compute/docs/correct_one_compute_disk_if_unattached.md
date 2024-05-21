# Correct one compute disk if unattached

## Overview

Compute disk which are not attached will still incur charges and provide no real use, these disks should be reviewed and if necessary tidied up.

This pipeline allows you to specify a single unattached compute disk and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_disk_if_unattached pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_disk_if_unattached).