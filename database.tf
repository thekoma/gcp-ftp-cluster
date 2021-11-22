resource "random_id" "db_name_suffix" {
  byte_length = 4
}

locals {
  onprem = [ "2.230.193.19/32", "0.0.0.0/0" ]
}


resource "google_sql_database_instance" "ftp" {
  name                = "ftp-${random_id.db_name_suffix.hex}"
  project             = "${var.project_id}-${random_id.project.hex}"
  region              = var.region
  database_version    = "MYSQL_8_0"
  deletion_protection = false
  depends_on = [ google_compute_network.vpc_network, google_project_organization_policy.enable_sql_public ]
  settings {
    tier = "db-n1-standard-1"
    ip_configuration {

      dynamic "authorized_networks" {
        for_each = local.onprem
        iterator = onprem

        content {
          name  = "onprem-${onprem.key}"
          value = onprem.value
        }
      }
    }
  }
}



# output "ftp" {
#   value = nonsensitive(google_sql_database_instance.ftp)
# }
resource "google_sql_database" "ftp" {
  name     = "ftp"
  instance = google_sql_database_instance.ftp.name
  charset = "utf8"
  collation = "utf8_general_ci"
}

resource "random_password" "dbpassword" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "google_sql_user" "users" {
  instance = google_sql_database_instance.ftp.name
  name     = var.sqlusername
  password = random_password.dbpassword.result
}
