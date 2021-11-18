variable region {
  default = "us-central1"
}

variable zone {
  default = "us-central1-b"
}

variable project_name {
  default = "An FTP Project"
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
  default = "${path.module}/credentials.json"
}

variable "network_name" {
  default = "default"
}

variable "source_ranges" {
  type    = list(string)
  default = ["35.235.240.0/20"]
}

# variable "ssh_keys" {
#   type    = string
#   default = <<EOF
#       dev:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILg6UtHDNyMNAh0GjaytsJdrUxjtLy3APXqZfNZhvCeT dev
#       foo:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILg6UtHDNyMNAh0GjaytsJdrUxjtLy3APXqZfNZhvCeT bar
#     EOF
# }

