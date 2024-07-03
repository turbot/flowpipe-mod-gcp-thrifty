# Correct Logging buckets with high retention

## Overview

Logging buckets can be costly to run, especially if they're rarely used, buckets with high retention periods should be reviewed to determine if they're still required.

This pipeline allows you to specify a collection of Logging buckets with high retention periods and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_logging_buckets_with_high_retention pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_logging_buckets_with_high_retention)
- [detect_and_correct_logging_buckets_with_high_retention trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_logging_buckets_with_high_retention)
