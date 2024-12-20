# Correct Redis instances exceeding max age

## Overview

Redis instances can be costly to run, especially if they're rarely used, instances that have been running for a long time should be reviewed to determine if they're still required.

This control allows you to specify a threshold for how long an instance has been running and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_redis_instances_exceeding_max_age pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_redis_instances_exceeding_max_age)
- [detect_and_correct_redis_instances_exceeding_max_age trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_redis_instances_exceeding_max_age)