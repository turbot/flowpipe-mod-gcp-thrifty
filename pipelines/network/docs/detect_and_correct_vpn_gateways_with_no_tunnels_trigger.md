# Detect & correct VPN Gateways with no tunnels

## Overview

VPN Gateways can be costly to run, especially if they're rarely used, gateways with no tunnels should be reviewed to determine if they're still required.

This query trigger detects VPN Gateways with no tunnels and then either sends a notification or attempts to perform a predefined corrective action.

### Getting Started

By default, this trigger is disabled, however it can be configured by [setting the below variables](https://flowpipe.io/docs/build/mod-variables#passing-input-variables)

- `vpn_gateways_with_no_tunnels_trigger_enabled` should be set to `true` as the default is `false`.
- `vpn_gateways_with_no_tunnels_trigger_schedule` should be set to your desired running [schedule](https://flowpipe.io/docs/flowpipe-hcl/trigger/schedule#more-examples)
- `vpn_gateways_with_no_tunnels_default_action` should be set to your desired action (i.e. `"notify"` for notifications or `"delete_vpn_gateway"` to delete the gateway).

Then starting the server:
```sh
flowpipe server
```

or if you've set the variables in a `.fpvars` file:
```sh
flowpipe server --var-file=/path/to/your.fpvars
```
