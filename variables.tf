variable region {
  default = "us-central1"
}

variable zone {
  default = "us-central1-b"
}


variable machine_type_bastion {
  default = "e2-standard-4"
}

variable machine_type_ftp {
  default = "e2-standard-4"
}
variable project_name {
  default = "An FTP Project"
}

variable folder_id {
  default = null
}


variable network {
  default = "default"
}

variable project_id {
  default = "project-id-1234567890"
}

variable org_id {
  default = "1234567890"
}

variable billing_account {
    default = "Your Billing Account"
}

# Note if the file is missing it will use the gcloud environment of your shell.
# I strongly suggest to use a service account
variable "gcp_auth_file" {
  type        = string
  description = "GCP authentication file"
  default = "./credentials.json"
}

variable "network_name" {
  default = "default"
}

# Note this is the monitoring range of google. Do not remove it
variable "source_ranges" {
  type    = list(string)
  default = [ "35.191.0.0/16", "130.211.0.0/22", "35.235.240.0/20"]
}

variable "sqlusername" {
  default = "sftpgo"
}

variable "ftp_demo_user" {
  default = "user"
}

variable "ftp_demo_password" {
  default = "password"
}

variable "ftp_demo_pubkey" {
  default = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/bcdef+iZ myuser@demo"
}

variable "ftp_webadmin_user" {
  default = "admin"
}

variable "ftp_webadmin_password" {
  default = "password"
}



variable "dns_project_id" {
  type = string
  default = "1234567890"
}

variable "dns_zone_name" {
  type = string
  default = "myftp"
}

variable "dns_record_name_bastion" {
  type = string
  default = "ftp"
}

variable "dns_record_name_lb" {
  type = string
  default = "haftp"
}

# You need a DNS zone
# If you want we can create one zone for you.
# If the zone already exist set create_dns_zone to false and 
# ignore dns_zone_value and dns_zone_visibility vars
variable "create_dns_zone" {
  type = bool
  default = "true"
}

variable "dns_zone_value" {
  type = string
  default = "ftp.gcpdomain."
}
variable "dns_zone_visibility" {
  type = string
  default = "private"
}
