# Correct AlloyDB instances exceeding max age

## Overview

AlloyDB instances can be costly to run, especially if they're rarely used, instances exceeding a certain age should be reviewed to determine if they're still required.

This pipeline detects AlloyDB instances exceeding a certain age and then either sends a notification or attempts to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_alloydb_instances_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_alloydb_instances_exceeding_max_age)
- [detect_and_correct_alloydb_instances_exceeding_max_age trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_alloydb_instances_exceeding_max_age)