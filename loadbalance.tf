resource "google_compute_target_tcp_proxy" "default" {
  name            = "ftp-proxy"
  backend_service = google_compute_target_pool.ftp.id
}
