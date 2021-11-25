resource "google_dns_managed_zone" "ftp_zone_create" {
  count = var.create_dns_zone ? 1 : 0
  name        = var.dns_zone_name
  dns_name    = var.dns_zone_value
  visibility =  var.dns_zone_visibility
}

data "google_dns_managed_zone" "ftp_zone" {
  name = var.dns_zone_name
  project = var.dns_project_id
}

locals {
  ftprecord = var.create_dns_zone ? "${var.dns_record_name_bastion}.${google_dns_managed_zone.ftp_zone_create[0].dns_name}" : "${var.dns_record_name_bastion}.${data.google_dns_managed_zone.ftp_zone.dns_name}"
  haftprecord = var.create_dns_zone ? "${var.dns_record_name_lb}.${google_dns_managed_zone.ftp_zone_create[0].dns_name}" : "${var.dns_record_name_lb}.${data.google_dns_managed_zone.ftp_zone.dns_name}"
  zone_name = var.create_dns_zone ? google_dns_managed_zone.ftp_zone_create[0].name : data.google_dns_managed_zone.ftp_zone.name
  
}

resource "google_dns_record_set" "haftp" {
  name = local.haftprecord
  type = "A"
  ttl  = 60
  project = var.dns_project_id
  managed_zone = local.zone_name
  rrdatas = [ google_compute_forwarding_rule.ftp.ip_address ]
  depends_on = [ google_compute_forwarding_rule.ftp, local.zone_name ]
}

resource "google_dns_record_set" "ftp" {
  name = local.ftprecord
  type = "A"
  ttl  = 60
  project = var.dns_project_id
  managed_zone = local.zone_name
  rrdatas = [ module.bastion_instance.instances_details[0].network_interface[0].access_config[0].nat_ip ]
  depends_on = [ module.bastion_instance, local.zone_name ]
}