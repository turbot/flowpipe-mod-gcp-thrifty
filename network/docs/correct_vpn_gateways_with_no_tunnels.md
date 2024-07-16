# Correct VPN Gateways with no tunnels

## Overview

VPN Gateways can be costly to run, especially if they're rarely used, gateways with no tunnels should be reviewed to determine if they're still required.

This pipeline allows you to specify a collection of VPN Gateways with no tunnels and then either send notifications or attempt to perform a predefined corrective action upon the collection.

Whilst it is possible to utilise this pipeline standalone, it is usually called from either:
- [detect_and_correct_vpn_gateways_with_no_tunnels pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.detect_and_correct_vpn_gateways_with_no_tunnels)
- [detect_and_correct_vpn_gateways_with_no_tunnels trigger](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/triggers/gcp_thrifty.trigger.query.detect_and_correct_vpn_gateways_with_no_tunnels)