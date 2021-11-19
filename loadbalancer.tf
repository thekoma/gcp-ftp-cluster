resource "google_compute_region_health_check" "ftp-check" {
  check_interval_sec = "5"
  healthy_threshold  = "2"
  name               = "ftp-check"
  project            = "${var.project_id}-${random_id.project.hex}"
  region             = var.region

  tcp_health_check {
    port         = "21"
    proxy_header = "NONE"
  }
  timeout_sec         = "5"
  unhealthy_threshold = "2"
    depends_on = [
      module.ftp_mig
    ]
}

resource "google_compute_region_backend_service" "ftp" {
  region                          = var.region
  health_checks                   = [ google_compute_region_health_check.ftp-check.id ]
  project                         = "${var.project_id}-${random_id.project.hex}"

  depends_on = [ google_compute_region_health_check.ftp-check ]

  affinity_cookie_ttl_sec         = "0"
  connection_draining_timeout_sec = "300"
  enable_cdn                      = "false"
  load_balancing_scheme           = "EXTERNAL"
  name                            = "ftp"
  port_name                       = "ftp"
  protocol                        = "TCP"
  session_affinity                = "CLIENT_IP"
  timeout_sec                     = "30"

  backend {
    balancing_mode               = "CONNECTION"
    capacity_scaler              = "0"
    failover                     = "false"
    group                        = module.ftp_mig.instance_group
    max_connections              = "0"
    max_connections_per_endpoint = "0"
    max_connections_per_instance = "0"
    max_rate                     = "0"
    max_rate_per_endpoint        = "0"
    max_rate_per_instance        = "0"
    max_utilization              = "0"
  }
}


resource "google_compute_forwarding_rule" "ftp" {
  depends_on             = [ google_compute_region_backend_service.ftp ]
  all_ports              = "true"
  allow_global_access    = "false"
  backend_service        = google_compute_region_backend_service.ftp.id
  ip_protocol            = "TCP"
  is_mirroring_collector = "false"
  load_balancing_scheme  = "EXTERNAL"
  name                   = "ftp-ip"
  network_tier           = "STANDARD"
  region                 = var.region
  project                = "${var.project_id}-${random_id.project.hex}"
}
