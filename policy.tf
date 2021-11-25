data "google_client_openid_userinfo" "me" {
}

resource "google_project_iam_member" "sa_iap_admin" {
  project = "${var.project_id}-${random_id.project.hex}"
  role    = "roles/iap.admin"
  member = length(regexall(".*gserviceaccount.com$", data.google_client_openid_userinfo.me.email)) > 0 ? "serviceAccount:${data.google_client_openid_userinfo.me.email}" : "user:${data.google_client_openid_userinfo.me.email}"

  depends_on = [
    module.project-services
  ]

}

resource "google_project_organization_policy" "public_ip_for_vm" {
  project    = "${var.project_id}-${random_id.project.hex}"
  provider   = google-beta
  constraint = "compute.vmExternalIpAccess"
  depends_on = [ google_project_iam_member.sa_iap_admin ]
  list_policy {
    allow {
      all = true
    }
  }
}

resource "google_project_organization_policy" "enable_sql_public" {
  project    = "${var.project_id}-${random_id.project.hex}"
  provider   = google-beta
  constraint = "sql.restrictAuthorizedNetworks"
  depends_on = [ google_project_iam_member.sa_iap_admin ]
  boolean_policy {
    enforced = false
  }
}

resource "google_project_organization_policy" "peering" {
  project    = "${var.project_id}-${random_id.project.hex}"
  provider   = google-beta
  constraint = "compute.restrictVpcPeering"
  depends_on = [ google_project_iam_member.sa_iap_admin ]
  list_policy {
    allow {
      all = true
    }
  }
}
