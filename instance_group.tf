resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  tcp_health_check {
    port = "22"
  }
}
resource "google_compute_target_pool" "ftp" {
  name = "ftp-pool"
}

resource "google_compute_instance_group_manager" "ftp" {
  name = "ftp"

  base_instance_name = "ftp"
  zone               = "us-central1-a"

  version {
    instance_template  = google_compute_instance_template.ftp.id
  }

  target_pools = [google_compute_target_pool.ftp.id]
  target_size  = 2

  named_port {
    name = "ftp"
    port = 21
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }
}


