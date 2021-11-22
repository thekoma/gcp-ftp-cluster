resource "random_id" "suffix" {
  byte_length = 8
}

resource "google_storage_bucket" "ansible" {
  name = "ansible-${random_id.suffix.hex}"
  uniform_bucket_level_access = true
  depends_on = [
    module.project-services
  ]
}

resource "google_storage_bucket_object" "playbook" {
  for_each = fileset("${path.module}/ansible", "**")
  bucket   = google_storage_bucket.ansible.name
  name     = "ansible/${each.key}"
  source   = "${path.module}/ansible/${each.key}"
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible
  ]
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