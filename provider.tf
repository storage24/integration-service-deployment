terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

terraform {
  backend "gcs" {
    bucket = "storage24-integration-services-terraform-state"  # The name of your GCS bucket
    prefix = "terraform/state"     # The path within the bucket to store state
  }
}

provider "google" {
  credentials = file("~/.config/gcloud/application_default_credentials.json")
  project     = var.project_id
  region      = var.region
}
