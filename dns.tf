locals {
  ftprecord = "${var.dns_record_name_bastion}.${var.dns_zone_value}"
  haftprecord = "${var.dns_record_name_lb}.${var.dns_zone_value}"
  dns_project_id = var.create_dns_zone ? "${var.project_id}-${random_id.project.hex}" : var.existing_dns_project_id
  network_url = var.dns_zone_visibility == "private" ? google_compute_network.vpc_network.id : null
  depends_on = [ module.project-services ]
}


data "google_project" "dns_project" {
  project_id = local.dns_project_id
  depends_on = [ module.project-services ]
}


resource "google_dns_managed_zone" "ftp_zone_create" {
  count       = var.create_dns_zone ? 1 : 0
  name        = var.dns_zone_name
  dns_name    = var.dns_zone_value
  visibility  =  var.dns_zone_visibility
  project     = data.google_project.dns_project.project_id
  depends_on  = [ module.project-services ]
  private_visibility_config {
    networks {
      network_url = local.network_url
    }
  }
}


data "google_dns_managed_zone" "ftp_zone" {
  name = var.dns_zone_name
  project = data.google_project.dns_project.project_id
  depends_on = [ module.project-services, data.google_project.dns_project ]
}

resource "google_dns_record_set" "haftp" {
  name = local.haftprecord
  type = "A"
  ttl  = 60
  project = local.dns_project_id
  managed_zone = var.dns_zone_name
  rrdatas = [ google_compute_forwarding_rule.ftp.ip_address ]
  depends_on = [ google_compute_forwarding_rule.ftp, data.google_dns_managed_zone.ftp_zone  ]
}

resource "google_dns_record_set" "ftp" {
  name = local.ftprecord
  type = "A"
  ttl  = 60
  project = local.dns_project_id
  managed_zone = var.dns_zone_name
  rrdatas = [ module.bastion_instance.instances_details[0].network_interface[0].access_config[0].nat_ip ]
  depends_on = [ google_compute_forwarding_rule.ftp, data.google_dns_managed_zone.ftp_zone, module.bastion_instance  ]
}