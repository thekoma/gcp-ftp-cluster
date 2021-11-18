resource "google_compute_firewall" "ftp-firewall-in" {
  name    = "ftp-firewall-in"
  network = var.network_name
  direction = "INGRESS"
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "21", "1000-2000"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["ftp"]
}


resource "google_compute_firewall" "admin-firewall-in" {
  name    = "admin-firewall-in"
  network = var.network_name
  direction = "INGRESS"
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.source_ranges
  target_tags = ["admin"]
}



resource "google_compute_firewall" "any-firewall-out" {
  name    = "any-firewall-out"
  network = var.network_name
  direction = "EGRESS"
  allow {
    protocol = "icmp"
  }
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "nat-router"
  network = var.network_name
  region  = var.region
}

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project_id
  region     = var.region
  router     = google_compute_router.router.name
}