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
  # keepers = { ansible_url = google_storage_bucket.ansible.url }
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
  # keepers = { sqlusername = var.sqlusername }
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
  depends_on = [ data.google_service_account.ftp, google_secret_manager_secret.sqlhost ]
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
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "cookie_key_v1" {
  secret      = google_secret_manager_secret.cookie_key.name
  secret_data = random_id.cookie_key.hex
  depends_on = [ random_id.cookie_key, google_secret_manager_secret.cookie_key ]
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


# NFS Server

resource "google_secret_manager_secret" "nfs_server" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "nfs_server"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "nfs_server_v1" {
  secret      = google_secret_manager_secret.nfs_server.name
  secret_data = google_filestore_instance.ftp.networks[0].ip_addresses[0]
  depends_on = [ google_filestore_instance.ftp ]
}

resource "google_secret_manager_secret_iam_member" "nfs_server_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.nfs_server.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    data.google_service_account.ftp
  ]
}


# NFS Server Mountpoint

resource "google_secret_manager_secret" "nfs_server_mount" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "nfs_server_mount"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "nfs_server_mount_v1" {
  secret      = google_secret_manager_secret.nfs_server_mount.name
  secret_data = google_filestore_instance.ftp.file_shares[0].name
  depends_on = [ google_filestore_instance.ftp ]
}

resource "google_secret_manager_secret_iam_member" "nfs_server_mount_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.nfs_server_mount.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    data.google_service_account.ftp
  ]
}
# FTP User
resource "google_secret_manager_secret" "ftp_demo_user" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "ftp_demo_user"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "ftp_demo_user_v1" {
  secret      = google_secret_manager_secret.ftp_demo_user.name
  secret_data = var.ftp_demo_user
}

resource "google_secret_manager_secret_iam_member" "ftp_demo_user_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.ftp_demo_user.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ module.project-services,data.google_service_account.ftp ]
}

# FTP Password
resource "google_secret_manager_secret" "ftp_demo_password" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "ftp_demo_password"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "ftp_demo_password_v1" {
  secret      = google_secret_manager_secret.ftp_demo_password.name
  secret_data = bcrypt(var.ftp_demo_password, 10) 
  lifecycle {
    ignore_changes = [ secret_data ]
  }
}

resource "google_secret_manager_secret_iam_member" "ftp_demo_password_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.ftp_demo_password.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ module.project-services, data.google_service_account.ftp ]
}


# FTP Pubkey
resource "google_secret_manager_secret" "ftp_demo_pubkey" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "ftp_demo_pubkey"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "ftp_demo_pubkey_v1" {
  secret      = google_secret_manager_secret.ftp_demo_pubkey.name
  secret_data = var.ftp_demo_pubkey
}

resource "google_secret_manager_secret_iam_member" "ftp_demo_pubkey_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.ftp_demo_pubkey.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ module.project-services, data.google_service_account.ftp ]
}

# FTP WebAdmin User
resource "google_secret_manager_secret" "ftp_webadmin_user" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "ftp_webadmin_user"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}

resource "google_secret_manager_secret_version" "ftp_webadmin_user_v1" {
  secret      = google_secret_manager_secret.ftp_webadmin_user.name
  secret_data = var.ftp_webadmin_user
}

resource "google_secret_manager_secret_iam_member" "ftp_webadmin_user_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.ftp_webadmin_user.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ module.project-services, data.google_service_account.ftp ]
}

# FTP WebAdmin Password
resource "google_secret_manager_secret" "ftp_webadmin_password" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = "ftp_webadmin_password"
  replication { automatic = true }
  depends_on = [ module.project-services ]
}


resource "google_secret_manager_secret_version" "ftp_webadmin_password_v1" {
  secret      = google_secret_manager_secret.ftp_webadmin_password.name
  secret_data = bcrypt(var.ftp_webadmin_password, 10)
  lifecycle {
    ignore_changes = [ secret_data ]
  }
}

resource "google_secret_manager_secret_iam_member" "ftp_webadmin_password_member" {
  project = "${var.project_id}-${random_id.project.hex}"
  secret_id = google_secret_manager_secret.ftp_webadmin_password.secret_id
  role = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${data.google_service_account.ftp.email}"
  depends_on = [ module.project-services, data.google_service_account.ftp ]
}
