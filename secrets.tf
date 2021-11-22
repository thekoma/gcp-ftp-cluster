#Bucket ID
resource "google_secret_manager_secret" "bucket_id" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "bucket_id"
  replication { automatic = true }
  depends_on = [ module.project-services, ]
}

resource "google_secret_manager_secret_version" "bucket_id_v1" {
  secret      = google_secret_manager_secret.bucket_id.name
  secret_data = google_storage_bucket.ansible.url
  depends_on = [ module.project-services, google_storage_bucket.ansible ]
}

resource "google_secret_manager_secret_iam_member" "bucket_id_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.bucket_id.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ data.google_service_account.ftp ]
}

# SQL Username
resource "google_secret_manager_secret" "sqlusername" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "sqlusername"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "sqlusername_v1" {
  secret      = google_secret_manager_secret.sqlusername.name
  secret_data = var.sqlusername
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_iam_member" "sqlusername_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.sqlusername.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ data.google_service_account.ftp ]
}

# SQL Host 
resource "google_secret_manager_secret" "sqlhost" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "sqlhost"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "sqlhost_v1" {
  secret      = google_secret_manager_secret.sqlhost.name
  secret_data = google_sql_database_instance.ftp.ip_address.0.ip_address
  depends_on = [ module.project-services, google_sql_database_instance.ftp ]
}

resource "google_secret_manager_secret_iam_member" "sqlhost_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.sqlhost.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ data.google_service_account.ftp, google_secret_manager_secret.sqlhost.secret_id ]
}

# DB Password
resource "google_secret_manager_secret" "sqlppass" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "sqlppass"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "sqlppass_v1" {
  secret      = google_secret_manager_secret.sqlppass.name
  secret_data = random_password.dbpassword.result
  depends_on = [ module.project-services, random_password.dbpassword ]
}

resource "google_secret_manager_secret_iam_member" "sqlppass_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.sqlppass.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ data.google_service_account.ftp ]
}

# Cookie KEY

resource "random_id" "cookie_key" {
  byte_length = 24
}
resource "google_secret_manager_secret" "cookie_key" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "cookie_key"
  replication { automatic = true }
}

resource "google_secret_manager_secret_version" "cookie_key_v1" {
  secret      = google_secret_manager_secret.cookie_key.name
  secret_data = random_id.cookie_key.hex
  depends_on = [
    random_id.cookie_key
  ]
}

resource "google_secret_manager_secret_iam_member" "cookie_key_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.cookie_key.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    data.google_service_account.ftp
  ]
}