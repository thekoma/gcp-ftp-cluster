terraform {
  required_providers {
    google-beta = {}
    null = {}
    random = {}
    time = {}
  }
}
provider "null" {}
provider "random" {}

resource "random_id" "project" {
  byte_length = 2
}

provider google {
  project = "${var.project_id}-${random_id.project.hex}"
  region = var.region
  credentials = fileexists(var.gcp_auth_file) ? file(var.gcp_auth_file) : null
}

provider "google-beta" {
  project = "${var.project_id}-${random_id.project.hex}"
  region = var.region  
  credentials = fileexists(var.gcp_auth_file) ? file(var.gcp_auth_file) : null
}

output "project-id" {
  value = "Project ID: ${var.project_id}-${random_id.project.hex}"
}

data "google_billing_account" "acct" {
  display_name = var.billing_account
  open         = true
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google"
  project_id              = "${var.project_id}-${random_id.project.hex}"
  folder_id               = var.folder_id
  name                    = var.project_name
  org_id                  = var.org_id
  billing_account         = data.google_billing_account.acct.id
  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "orgpolicy.googleapis.com",
    "oslogin.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

data "google_project" "main" {
  project_id = "${var.project_id}-${random_id.project.hex}"
  depends_on = [ module.project-services ]
}

resource "google_compute_network" "vpc_network" {
  project                 = "${var.project_id}-${random_id.project.hex}"
  name                    = var.network_name
  auto_create_subnetworks = true
  mtu                     = 1460
  depends_on = [ module.project-services ]
}

data "google_compute_network" "vpc_network" {
  name    = var.network_name
  project = "${var.project_id}-${random_id.project.hex}"
  depends_on = [ google_compute_network.vpc_network ]
}