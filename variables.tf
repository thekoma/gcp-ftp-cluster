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


variable "gcp_auth_file" {
  type        = string
  description = "GCP authentication file"
  default = "./credentials.json"
}

variable "network_name" {
  default = "default"
}

