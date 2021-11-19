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
  depends_on = [ google_compute_network.vpc_network ]
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
    ports    = ["22", "80", "443", "21", "8080", "2121", "2021", "2020" ]
  }
  source_ranges = var.source_ranges
  
  depends_on = [ google_compute_network.vpc_network ]
}

###########
resource "google_compute_firewall" "bastion-firewall-machines-from" {
  name    = "bastion-machines-can-to-machines"
  network = var.network_name
  direction = "INGRESS"
  allow {
    protocol = "all"
  }
  source_tags = ["bastion"]
  depends_on = [ google_compute_network.vpc_network ]
}


resource "google_compute_firewall" "bastion-firewall-machines-to" {

  name    = "bastion-machines-can-to-any"
  network = var.network_name
  direction = "EGRESS"
  allow {
    protocol = "all"
  }
  destination_ranges = ["0.0.0.0/0"]
  target_tags = ["bastion"]
  depends_on = [ google_compute_network.vpc_network ]
}
##########



resource "google_compute_firewall" "ftp-machines-high" {

  name    = "ftp-machines-high"
  network = var.network_name
  direction = "EGRESS"
  allow {
    protocol = "TCP"
    ports = [ "1024-65534" ]
  }
  destination_ranges = ["0.0.0.0/0"]
  target_tags = ["ftp"]
  depends_on = [ google_compute_network.vpc_network ]
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
    ports    = ["80", "443", "3306"]
  }

  destination_ranges = ["0.0.0.0/0"]
  depends_on = [ google_compute_network.vpc_network ]
}