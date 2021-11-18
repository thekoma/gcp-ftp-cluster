terraform {
  required_providers {
    google = {
      version = "~> 3.30"
    }
    google-beta = {
      version = "~> 3.38"
    }
    null = {
      version = "~> 2.1"
    }
    random = {
      version = "~> 2.2"
    }
  }
}

provider google {
  project = var.project_id
  region = var.region
  credentials = fileexists(var.gcp_auth_file) ? file(var.gcp_auth_file) : null
}

provider "google-beta" {
  project = var.project_id
  region = var.region  
  credentials = fileexists(var.gcp_auth_file) ? file(var.gcp_auth_file) : null
}

provider "null" {}
provider "random" {}

data "google_billing_account" "acct" {
  display_name = var.billing_account
  open         = true
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 10.1"
  project_id              = var.project_id
  name                    = var.project_name
  org_id                  = var.org_id
  billing_account         = data.google_billing_account.acct.id
  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "orgpolicy.googleapis.com"
  ]
}

resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = true
  mtu                     = 1460
}

data "google_compute_network" "vpc_network" {
  name    = var.network_name
  project = var.project_id
}