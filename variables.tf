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
  default = [ "35.191.0.0/16", "130.211.0.0/22" ]
}

variable "sqlusername" {
  default = "sftpgo"
}
