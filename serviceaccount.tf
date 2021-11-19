data "google_compute_default_service_account" "default" {
}

resource "google_service_account" "ftp" {
  account_id   = "ftp-service-account"
  disabled     = false
  depends_on = [
    module.project-services,
  ]
}

data "google_service_account" "ftp" {
  account_id = google_service_account.ftp.id
  depends_on = [
    module.project-services,
    google_service_account.ftp
  ]
}

resource "google_project_iam_custom_role" "forwardingRulesSa" {
  role_id     = "custom.forwardingRulesSa"
  title       = "A Role to permit the listing of the IP"
  description = ""
  permissions = ["compute.forwardingRules.list", "compute.forwardingRules.get"]
  project     = "${var.project_id}-${random_id.project.hex}"
}

resource "google_project_iam_member" "sa-forwardingRules" {
  project = "${var.project_id}-${random_id.project.hex}"
  role    = google_project_iam_custom_role.forwardingRulesSa.id
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    google_service_account.ftp,
    google_project_iam_custom_role.forwardingRulesSa
  ]
}

resource "google_project_iam_member" "view-secrets" {
  project = "${var.project_id}-${random_id.project.hex}"
  role    = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    google_service_account.ftp,
  ]
}


