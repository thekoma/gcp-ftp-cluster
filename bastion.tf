resource "google_compute_instance" "bastion" {
  name         = "bastion"
  zone         = var.zone
  machine_type             = "e2-micro"
  can_ip_forward           = false

  tags = ["bastion", "admin"]

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }


  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral public IP
    }
  }


  shielded_instance_config {
      enable_secure_boot = true
      enable_vtpm = true
      enable_integrity_monitoring = true
  }
#   metadata_startup_script = "echo hi > /test.txt"

}