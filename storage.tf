resource "random_id" "suffix" {
  byte_length = 8
}

resource "google_storage_bucket" "ansible" {
  name = "ansible-${random_id.suffix.hex}"
  uniform_bucket_level_access = true
  depends_on = [ module.project-services ]
  force_destroy = true
  location = var.bucket_zone
}

resource "google_storage_bucket_object" "playbook" {
  for_each = fileset("${path.module}/ansible", "**")
  bucket   = google_storage_bucket.ansible.name
  name     = "ansible/${each.key}"
  source   = "${path.module}/ansible/${each.key}"
  depends_on = [ module.project-services, google_storage_bucket.ansible ]
}

resource "google_storage_bucket_object" "demo" {
  for_each = fileset("${path.module}/demo", "**")
  bucket   = google_storage_bucket.ansible.name
  name     = "demo/${each.key}"
  source   = "${path.module}/demo/${each.key}"
  depends_on = [ module.project-services, google_storage_bucket.ansible ]
}

resource "google_project_iam_member" "bucket_viewer_ftp" {
  project = "${var.project_id}-${random_id.project.hex}"
  role    = "roles/storage.objectViewer"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    module.project-services,
    google_storage_bucket_object.playbook,
    data.google_service_account.ftp
  ]
}

resource "google_filestore_instance" "ftp" {
  project = "${var.project_id}-${random_id.project.hex}"
  name = "ftp"
  zone = var.zone
  # region = var.region
  tier = "STANDARD"

  file_shares {
    capacity_gb = 1024
    name        = "ftp"
  }

  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }
    depends_on = [ module.project-services, google_project_organization_policy.peering ]
  }

output "nfs" {
  value = google_filestore_instance.ftp
  depends_on = [ google_filestore_instance.ftp ]
  sensitive = true
}


output "nfs_ip" {
  value = google_filestore_instance.ftp.networks[0].ip_addresses[0]
  depends_on = [ google_filestore_instance.ftp ]
  sensitive = true

}
output "nfs_mountpoint" {
  value = google_filestore_instance.ftp.file_shares[0].name
  depends_on = [ google_filestore_instance.ftp ]
  sensitive = true
}
