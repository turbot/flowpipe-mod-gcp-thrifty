# Correct one VPN Gateway with no tunnels

VPN Gateways can be costly to run, especially if they're rarely used, gateways with no tunnels should be reviewed to determine if they're still required.

This pipeline allows you to specify a single instance and then either send a notification or attempt to perform a predefined corrective action.

Whilst it is possible to utilise this pipeline standalone, it is usually called from the
[correct_one_vpn_gateway_with_no_tunnels_pipeline pipeline](https://hub.flowpipe.io/mods/turbot/gcp_thrifty/pipelines/gcp_thrifty.pipeline.correct_one_vpn_gateway_with_no_tunnels_pipeline).