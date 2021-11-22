module "instance_template" {
  source          = "terraform-google-modules/vm/google//modules/instance_template"
  region          = var.region
  project_id          = "${var.project_id}-${random_id.project.hex}"
  # subnetwork      = var.subnetwork
  machine_type         = var.machine_type_bastion
  source_image_project = "ubuntu-os-cloud"
  source_image_family  = "ubuntu-2004-lts"
  tags                 = ["bastion", "admin"]
  network              = data.google_compute_network.vpc_network.id
  enable_shielded_vm   = true
  name_prefix          = "bastion"
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
  service_account = {
    email  = data.google_service_account.ftp.email
    # email  = data.google_compute_default_service_account.default.email
    scopes = ["compute-ro", "storage-ro", "logging-write", "monitoring-write", "service-control", "service-management", "pubsub", "trace", "cloud-platform"]
  }
  depends_on = [
    module.project-services,
    google_storage_bucket.ansible,
    google_compute_network.vpc_network,
    google_project_iam_member.sa_iap_admin,
    google_project_organization_policy.public_ip_for_vm,
    google_service_account.ftp
  ]
}

data "google_compute_subnetwork" "bastion-subnetwork" {
  name   = var.network_name
  region = var.region
  depends_on = [
    module.project-services,
    google_compute_network.vpc_network,
    google_project_organization_policy.public_ip_for_vm
  ]
}

module "bastion_instance" {
  source            = "terraform-google-modules/vm/google//modules/compute_instance"
  subnetwork        = data.google_compute_subnetwork.bastion-subnetwork.name
  region            = var.region
  zone              = var.zone
  num_instances     = 1
  hostname          = "bastion"
  instance_template = module.instance_template.self_link
  access_config     = [ {
    nat_ip = null
    network_tier = null
  } ]
  depends_on        = [
    module.instance_template,
    data.google_compute_subnetwork.bastion-subnetwork
  ]
}