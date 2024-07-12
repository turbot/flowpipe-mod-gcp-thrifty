locals {
  kubernetes_common_tags = merge(local.gcp_thrifty_common_tags, {
    service = "GCP/Kubernetes"
  })
}
