resource "google_compute_router" "router" {
  project = "${var.project_id}-${random_id.project.hex}"
  name    = "nat-router"
  network = var.network_name
  region  = var.region
  depends_on = [ google_compute_network.vpc_network ]  
}

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  # version    = "~> 1.2"
  project_id = "${var.project_id}-${random_id.project.hex}"
  region     = var.region
  router     = google_compute_router.router.name
  depends_on = [ 
    google_compute_network.vpc_network,
    google_compute_router.router
  ]
}