# Correct one compute address if unattached

## Overview

Compute  addresses are a costly resource to maintain, if they are unattached you will be accruing costs without any benefit; therefore unattached compute  addresses should be released if not required.

This pipeline allows you to specify a single unattached compute  addresses and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the [correct_compute_addresses_if_unattached pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_compute_addresses_if_unattached).
