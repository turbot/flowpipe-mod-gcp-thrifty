# Correct Compute addresses if unattached

## Overview

Compute addresses are a costly resource to maintain, if they are unattached you will be accruing costs without any benefit; therefore unattached compute addresses should be released if not required.

This pipeline allows you to specify a collection of unattached compute addresses and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_compute_addresses_if_unattached pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_compute_addresses_if_unattached)
- [detect_and_correct_compute_addresses_if_unattached trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_compute_addresses_if_unattached)