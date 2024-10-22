mod "gcp_thrifty" {
  title         = "GCP Thrifty"
  description   = "Run pipelines to detect and correct GCP resources that are unused and underutilized."
  color         = "#ea4335"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/gcp-thrifty.svg"
  categories    = ["gcp", "cost", "public cloud", "standard", "thrifty"]
  database      = var.database

  opengraph {
    title       = "GCP Thrifty Mod for Flowpipe"
    description = "Run pipelines to detect and correct GCP resources that are unused and underutilized."
    image       = "/images/mods/turbot/gcp-thrifty-social-graphic.png"
  }

  require {
    flowpipe {
      min_version = "1.0.0"
    }
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "v1"
    }
    mod "github.com/turbot/flowpipe-mod-gcp" {
      version = "v1"
    }
  }
}
