# https://raw.githubusercontent.com/tapanbanker/terraform-ansible-gcp/master/main.tf
module "ftp_instance_template" {
  service_account = {
    email  = data.google_service_account.ftp.email
    scopes = ["compute-ro", "storage-ro", "logging-write", "monitoring-write", "service-control", "service-management", "pubsub", "trace", "cloud-platform"]
  }
  source               = "terraform-google-modules/vm/google//modules/instance_template"
  # version              = "~> 2.1.0"
  machine_type         = var.machine_type_ftp
  source_image_project = "ubuntu-os-cloud"
  source_image_family  = "ubuntu-2004-lts"
  name_prefix          = "ftp"
  tags                 = ["ftp"]
  network              = data.google_compute_network.vpc_network.id
  enable_shielded_vm   = true
  metadata = {
    enable-oslogin = "TRUE"
    user-data      = <<EOT
        #cloud-config
        packages: ["ansible", "expect"]
        write_files:
        - path: /etc/ansible/ansible.cfg
          content: |
              [defaults]
              remote_tmp     = /tmp
              local_tmp      = /tmp
        runcmd:
        - gsutil cp -r ${google_storage_bucket.ansible.url}/ansible /opt
        - ansible-playbook /opt/ansible/rerun-pb.yml
        - sh -c /opt/rerun.sh
      EOT
  }
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    google_compute_network.vpc_network,
    google_project_iam_member.sa_iap_admin,
    data.google_compute_default_service_account.default,
    data.google_service_account.ftp
  ]
}


module "ftp_mig" {
  source              = "terraform-google-modules/vm/google//modules/mig"
  # version             = "~> 2.1.0"
  instance_template   = module.ftp_instance_template.self_link
  region              = var.region
  autoscaling_enabled = true
  target_size         = 3
  project_id          = "${var.project_id}-${random_id.project.hex}"
  hostname            = "ftp"
  # target_tags         = [ "ftp" ]
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    google_compute_network.vpc_network,
    google_project_iam_member.sa_iap_admin,
    module.ftp_instance_template,
    google_sql_user.users
  ]
  health_check_name = "mig-https-hc"
  health_check = {
    type                = "http"
    initial_delay_sec   = 120
    check_interval_sec  = 5
    healthy_threshold   = 1
    timeout_sec         = 5
    unhealthy_threshold = 10
    response            = ""
    proxy_header        = "NONE"
    port                = 80
    request             = ""
    request_path        = "/healthz"
    host                = ""
  }
}


module "gce-lb-http" {
  count           = 0
  source            = "GoogleCloudPlatform/lb-http/google"
  # version           = "~> 4.4"
  project           = "${var.project_id}-${random_id.project.hex}"
  name              = "group-http-lb"
  target_tags       = [ "ftp" ]
  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 10
      enable_cdn                      = false
      custom_request_headers          = null
      custom_response_headers         = null
      security_policy                 = null

      connection_draining_timeout_sec = null
      session_affinity                = null
      affinity_cookie_ttl_sec         = null

      health_check = {
        check_interval_sec  = null
        timeout_sec         = null
        healthy_threshold   = null
        unhealthy_threshold = null
        request_path        = "/healthz"
        port                = 80
        host                = null
        logging             = null
      }

      log_config = {
        enable = true
        sample_rate = 1.0
      }

      groups = [
        {
          # Each node pool instance group should be added to the backend.
          group                        = module.ftp_mig.instance_group
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        },
      ]

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }
    }
  }
}