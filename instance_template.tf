resource "google_compute_instance_template" "ftp" {
  name                 = "ftp-template"
  description          = "This is an FTP template."
  tags                 = ["ftp"]

  labels               = {
    environment        = "prod"
  }

  instance_description     = "Thisis an FTP server"
  machine_type             = "e2-micro"
  can_ip_forward           = false

  shielded_instance_config {
      enable_secure_boot = true
      enable_vtpm = true
      enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image        = "debian-cloud/debian-11"
    auto_delete         = true
    boot                = true
  }

  // Use an existing disk resource
#   disk {
#     // Instance Templates reference disks by name, not self link
#     source      = google_compute_disk.foobar.name
#     auto_delete = false
#     boot        = false
#   }

  network_interface {
    network = data.google_compute_network.vpc_network.name
  }

  metadata = {
    foo = "bar"
  }
}