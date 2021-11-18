data "google_client_openid_userinfo" "me" {
}

output "me_info" {
  value = data.google_client_openid_userinfo.me
}


resource "google_project_iam_member" "sa_iap_admin" {
  project = var.project_id
  role    = "roles/iap.admin"
  # member  = "serviceAccount:${local.whoami.client_email}"
  member = length(regexall(".*iam.gserviceaccount.com$", data.google_client_openid_userinfo.me.email)) > 0 ? "serviceAccount:${data.google_client_openid_userinfo.me.email}" : "user:${data.google_client_openid_userinfo.me.email}"
}


data "google_project_organization_policy" "public_ip_for_vm" {
  project    = var.project_id
  constraint = "compute.vmExternalIpAccess"
}

# output "public_ip_for_vm_dump" {
#   value = data.google_project_organization_policy.public_ip_for_vm
# }

resource "google_project_organization_policy" "public_ip_for_vm" {
  project    = var.project_id
  provider   = google-beta
  constraint = "compute.vmExternalIpAccess"
  depends_on = [ google_project_iam_member.sa_iap_admin ]
  list_policy {
    allow {
      all = true
    }
  }
}
