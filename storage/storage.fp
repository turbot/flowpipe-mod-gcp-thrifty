locals {
  storage_common_tags = merge(local.gcp_thrifty_common_tags, {
    service = "GCP/Storage"
  })
}
