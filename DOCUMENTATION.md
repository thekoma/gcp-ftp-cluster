# GCP FTP Cluster Documentation

This document provides a comprehensive guide to deploying, configuring, and managing the GCP FTP Cluster solution.

## Table of Contents

1. [Introduction](#1-introduction)
    - [Purpose](#purpose)
    - [Core Technologies](#core-technologies)
    - [GCP Services Used](#gcp-services-used)
2. [Prerequisites](#2-prerequisites)
3. [Architecture](#3-architecture)
    - [Conceptual Diagram](#conceptual-diagram)
    - [Network Configuration](#network-configuration)
    - [Bastion Host](#bastion-host)
    - [FTP Cluster (Managed Instance Group - MIG)](#ftp-cluster-mig)
    - [Load Balancer](#load-balancer)
    - [Storage Solutions](#storage-solutions)
    - [Configuration and Secrets Management](#configuration-and-secrets-management)
    - [DNS](#dns)
4. [Deployment](#4-deployment)
    - [Setup](#setup)
    - [Terraform Execution](#terraform-execution)
5. [Configuration Details](#5-configuration-details)
    - [Terraform Variables (`variables.tf`)](#terraform-variables)
    - [SFTPGo Configuration](#sftpgo-configuration)
    - [Ansible Automation](#ansible-automation)
    - [Secret Management](#secret-management)
6. [Usage](#6-usage)
    - [Accessing FTP/SFTP Service](#accessing-ftpsftp-service)
    - [Accessing SFTPGo Admin Web UI](#accessing-sftpgo-admin-web-ui)
    - [Accessing the Bastion Host](#accessing-the-bastion-host)
7. [Troubleshooting](#7-troubleshooting)
    - [Common Deployment Issues](#common-deployment-issues)
    - [Checking Logs](#checking-logs)
    - [Service Health](#service-health)
8. [Terraform Outputs](#8-terraform-outputs)
9. [Cleanup](#9-cleanup)
10. [Customization](#10-customization)

---

## 1. Introduction

<a name="purpose"></a>
### Purpose
This project deploys a highly available and scalable File Transfer Protocol (FTP) / Secure File Transfer Protocol (SFTP) cluster on Google Cloud Platform (GCP). It is designed for users and organizations requiring robust, secure, and manageable file transfer capabilities, integrated with various GCP storage backends and managed through modern infrastructure-as-code and configuration management practices.

<a name="core-technologies"></a>
### Core Technologies
- **Terraform:** Used as the Infrastructure as Code (IaC) tool for declaratively provisioning and managing all GCP resources. This includes networking infrastructure, compute instances, databases, storage services, and IAM policies.
- **Ansible:** Employed for configuration management on the provisioned compute instances. It automates the installation of necessary software, configures the SFTPGo server, manages configuration files, and fetches dynamic configuration data (like secrets).
- **Docker:** The SFTPGo application is run within Docker containers. This ensures consistent runtime environments across different instances and simplifies the deployment and update process for the SFTPGo server.
- **SFTPGo:** A versatile and feature-rich FTP/SFTP server software. It supports multiple protocols (FTP, SFTP, WebDAV), various storage backends (local, GCS, S3, etc.), fine-grained user management, and an administrative web interface.

<a name="gcp-services-used"></a>
### GCP Services Used
- **Compute Engine:**
    - **Virtual Machines (VMs):** Provides the underlying compute resources for the bastion host and the individual FTP server instances within the Managed Instance Group.
    - **Managed Instance Groups (MIGs):** Offers scalability and high availability for the FTP server instances. The MIG ensures a defined number of instances are running, automatically repairs or replaces unhealthy instances, and can support autoscaling.
- **Cloud SQL (MySQL):** A fully managed relational database service. This project uses a MySQL 8.0 instance to store SFTPGo's metadata, including user accounts, administrator details, permissions, virtual folder configurations, and other application settings.
- **Cloud Storage (GCS):**
    - One GCS bucket is utilized to store Ansible playbooks, templates, and related automation files. Compute instances download these files during their setup and configuration process.
    - GCS also serves as a backend storage option for SFTPGo users' virtual folders, as demonstrated with the pre-configured demo user.
- **Filestore:** A managed Network File System (NFS) service. It provides a shared file system that can be mounted by multiple instances simultaneously and is used as another backend storage option for SFTPGo virtual folders.
- **Networking:**
    - **Virtual Private Cloud (VPC):** Forms the foundational private network for all deployed resources, ensuring isolation and control.
    - **Cloud Load Balancing:** A Regional TCP Network Load Balancer is used to distribute incoming FTP/SFTP traffic across the healthy instances in the MIG.
    - **Cloud NAT and Cloud Router:** Enable instances without public IP addresses (or those that only need public IPs for specific ingress) to initiate outbound connections to the internet (e.g., for downloading software packages or accessing GCP APIs).
    - **Firewall Rules:** Define and enforce network traffic policies, controlling inbound and outbound connections to and from the instances, thereby securing the deployment.
- **Secret Manager:** Provides secure storage, versioning, and access control for sensitive data such as database passwords, API keys, and application-specific credentials.
- **Identity and Access Management (IAM):** Manages permissions for users and service accounts, ensuring that resources are accessed securely and adhering to the principle of least privilege. A dedicated service account is created for the FTP application components.
- **Cloud DNS:** (Optional) Can be used to manage DNS records for the service endpoints (bastion host, load balancer), making them accessible via user-friendly and stable domain names.

---

## 2. Prerequisites

Before proceeding with the deployment of the FTP cluster, ensure the following requirements are met:

-   **Google Cloud Project:** An active GCP project with billing enabled is required.
-   **User/Service Account Permissions:** The identity (Google Cloud user or service account) that will execute the Terraform commands must possess sufficient IAM permissions. The `README.md` for this project suggests the following roles, which are typically needed at the Folder or Organization level if Terraform is also tasked with creating the project itself:
    -   `roles/iap.admin` (IAP Policy Admin)
    -   `roles/billing.admin` (Billing Account Administrator)
    -   `roles/resourcemanager.projectCreator` (Project Creator)
    -   Additionally, permissions for managing specific services will be needed if not covered by the above, such as:
        -   `roles/serviceusage.serviceUsageAdmin` (to enable necessary GCP service APIs)
        -   `roles/iam.serviceAccountAdmin` and `roles/iam.serviceAccountUser` (for service account management)
        -   Roles for managing Compute Engine, Cloud SQL, Filestore, GCS, Secret Manager, Cloud DNS, etc. (e.g., `roles/compute.admin`, `roles/cloudsql.admin`).
-   **`gcloud` Command-Line Tool:** The Google Cloud CLI (`gcloud`) must be installed on the machine where you will run Terraform. It should be authenticated with an identity that holds the necessary permissions mentioned above.
-   **Terraform:** Terraform (version compatible with the providers specified in `main.tf`, e.g., Google provider `~> 4.0`) must be installed locally.
-   **GCP Authentication File (Optional):** If you are not using Application Default Credentials (ADC) obtained via `gcloud auth application-default login`, you may need to use a service account key JSON file. The path to this file can be specified using the `gcp_auth_file` variable in `variables.tf` (default path: `./credentials.json`). Using ADC is generally recommended for better security.

---

## 3. Architecture

<a name="conceptual-diagram"></a>
### Conceptual Diagram

```
                               +-------------------------+
                               |      End Users          |
                               +-----------+-------------+
                                           | (FTP/SFTP/HTTP)
                                           v
                               +-------------------------+
                               | Regional TCP Load Balancer|
                               | (haftp.yourdomain.com)  |
                               +-----------+-------------+
                                           | (Traffic Distribution)
                  +------------------------+------------------------+
                  |                                                 |
                  v                                                 v
+-----------------------------------+      +-----------------------------------+
|   FTP Instance 1 (SFTPGo/Docker)  |      |   FTP Instance N (SFTPGo/Docker)  |
|   (Managed Instance Group)        | ...  |   (Managed Instance Group)        |
+-----------------+-----------------+      +-----------------+-----------------+
                  | (Metadata R/W)                            | (Metadata R/W)
                  |                                           |
                  |   +-----------------------------------+   |
                  +-->|      Cloud SQL (MySQL)            |<--+
                      |      (SFTPGo Metadata)            |
                      +-----------------------------------+

+-------------------------+      +-----------------------------------+      +-----------------------------------+
|     Bastion Host        |<---->|     Google Secret Manager         |<---->|     FTP Instances / Bastion       |
| (Admin, Ansible Control)|      |     (DB Pass, API Keys, etc.)     |      |     (Service Account for Access)  |
+-------------------------+      +-----------------------------------+      +-----------------------------------+

+-------------------------+      +-----------------------------------+      +-----------------------------------+
| FTP Instances / Bastion |<---->|     Google Cloud Storage (GCS)    |<---->|     SFTPGo (Virtual Folders)      |
| (Mounts/Accesses)       |      | (Ansible Playbooks, Demo Data)    |      |     (e.g., /gcs/*)                |
+-------------------------+      +-----------------------------------+      +-----------------------------------+

+-------------------------+      +-----------------------------------+      +-----------------------------------+
| FTP Instances / Bastion |<---->|     Google Filestore (NFS)        |<---->|     SFTPGo (Virtual Folders)      |
| (Mounts NFS Share)      |      | (Shared Filesystem)               |      |     (e.g., /nfs/*)                |
+-------------------------+      +-----------------------------------+      +-----------------------------------+

Other Components:
- VPC Network, Subnets, Cloud NAT, Cloud Router, Firewall Rules
- Cloud DNS (Optional, for *.yourdomain.com records)
- IAM (Service Accounts, Roles)
```

**Flow Description:**
1.  **User Connection:** End users connect to the FTP/SFTP service using the Load Balancer's public DNS name/IP. The Load Balancer also serves the SFTPGo Web Admin UI.
2.  **Traffic Distribution:** The Regional TCP Load Balancer distributes incoming connections across the healthy FTP instances within the Managed Instance Group (MIG).
3.  **FTP Instances:** Each instance in the MIG runs SFTPGo inside a Docker container. These instances handle the actual file transfer operations.
4.  **Metadata Storage:** SFTPGo instances read and write metadata (user accounts, permissions, folder structures) to a central Cloud SQL (MySQL) database. This makes the FTP instances themselves stateless.
5.  **Data Storage (Virtual Folders):**
    -   Users' virtual folders in SFTPGo can be mapped to various backends:
        -   Google Cloud Storage (GCS): For object storage.
        -   Google Filestore (NFS): For shared file system storage.
        -   Local instance storage (though less common in this HA setup for shared data).
6.  **Bastion Host:** Provides a secure administrative entry point. It runs Ansible, which can be used for initial setup (like seeding the SFTPGo database) and ongoing configuration management.
7.  **Configuration & Secrets:**
    -   Ansible playbooks and templates are stored in a GCS bucket and pulled by instances.
    -   Sensitive data (database passwords, API keys, user credentials for SFTPGo) are stored securely in Google Secret Manager and accessed by instances/Ansible as needed.
8.  **Networking:** All components reside within a VPC network, with Cloud NAT and Router for internet egress, and Firewall Rules controlling traffic flow.
9.  **DNS:** Cloud DNS can resolve public hostnames to the Load Balancer and Bastion IPs.

<a name="network-configuration"></a>
### Network Configuration
-   **VPC Network:** The deployment utilizes a VPC network, specified by the `network_name` variable (defaulting to `"default"`). All resources are launched within this network. The `main.tf` file manages the creation or referencing of this network (`google_compute_network.vpc_network`).
-   **Subnets:** While `auto_create_subnetworks = true` is set for the `google_compute_network` resource, the configuration primarily relies on automatically created subnets within the chosen region or the default subnet. The bastion host, for example, uses a data source `google_compute_subnetwork.bastion-subnetwork` that references `var.network_name` to find its subnetwork.
-   **Cloud Router & NAT (`network.tf`):**
    -   A `google_compute_router` (named `nat-router`) is created in the specified region and associated with the VPC network.
    -   The `terraform-google-modules/cloud-nat/google` module is used to set up Cloud NAT, linked to this router. This allows instances within the VPC (like the FTP servers and the bastion host, which may not have public IPs or only use them for specific ingress traffic) to initiate outbound connections to the internet (e.g., for downloading software packages, or accessing GCS for Ansible playbooks).
-   **Firewall Rules (`firewall.tf`):** Several `google_compute_firewall` resources are defined to control network traffic:
    -   `ftp-firewall-in`:
        -   Direction: `INGRESS`
        -   Network: `var.network_name`
        -   Target Tags: `["ftp"]` (applies to FTP instances in the MIG)
        -   Allow: ICMP, TCP on ports `22` (SFTP/SSH), `21` (FTP command), `1000-2000` (intended for passive FTP, though SFTPGo's default is `50000-50100`. This rule might need adjustment for the actual passive port range used by SFTPGo).
        -   Source Ranges: `0.0.0.0/0` (any source).
    -   `admin-firewall-in`:
        -   Direction: `INGRESS`
        -   Network: `var.network_name`
        -   Allow: ICMP, TCP on ports `22`, `80`, `443`, `21`, `8080` (SFTPGo web UI), `2121` (SFTPGo internal FTP port), `2021`, `2020`.
        -   Source Ranges: `var.source_ranges` (defaults to Google's health check ranges, IAP ranges: `35.191.0.0/16`, `130.211.0.0/22`, `35.235.240.0/20`).
    -   `bastion-firewall-machines-from`: Allows all ingress traffic from instances tagged `bastion` to any other instance in the network.
    -   `bastion-firewall-machines-to`: Allows all egress traffic from instances tagged `bastion` to any destination (`0.0.0.0/0`).
    -   `ftp-machines-high`: Allows egress TCP on high ports (`1024-65534`) from instances tagged `ftp` to any destination. This can be for active FTP data connections (though disabled by default in SFTPGo) or other ephemeral port communications.
    -   `any-firewall-out`: Allows egress ICMP and TCP on ports `80`, `443`, `3306` (MySQL) from any instance to any destination.

<a name="bastion-host"></a>
### Bastion Host
(Defined in `bastion.tf`)
-   **Purpose:** A single Compute Engine VM instance designed as a secure administrative entry point. It is used to run Ansible playbooks for its own setup and potentially for the initial data seeding of SFTPGo (e.g., creating the admin and demo users via `sftp-init.json` when the database is first set up).
-   **Instance Template:** Created using `module "instance_template"` (source: `terraform-google-modules/vm/google//modules/instance_template`) with `name_prefix = "bastion"`.
    -   Machine Type: `var.machine_type_bastion` (default: `e2-standard-4`).
    -   Image: Ubuntu 20.04 LTS (from `ubuntu-os-cloud/ubuntu-2004-lts`).
    -   Tags: `["bastion", "admin"]`.
    -   Service Account: Uses the shared FTP service account (`data.google_service_account.ftp.email`).
    -   Startup Script (`user-data` in `metadata`):
        -   Installs `ansible`, `expect`, `python3-passlib`, `python3-bcrypt`.
        -   Configures Ansible defaults (`/etc/ansible/ansible.cfg`).
        -   Copies Ansible playbook files from the GCS bucket (URL from `google_storage_bucket.ansible.url`) to `/opt/ansible` using `gsutil`.
        -   Runs `ansible-playbook /opt/ansible/rerun-pb.yml`.
        -   Executes `/opt/rerun.sh` (this script is templated by Ansible and also runs the playbook, forming part of a self-update mechanism via cron).
-   **Instance Creation:** `module "bastion_instance"` (source: `terraform-google-modules/vm/google//modules/compute_instance`) creates one instance from the template.
    -   Hostname: `bastion`.
    -   Access Config: Configured for a NAT IP, meaning it gets an ephemeral public IP address.
-   **DNS:** An 'A' record (e.g., `ftp.yourdomain.com`, derived from `var.dns_record_name_bastion` and `var.dns_zone_value`) is created pointing to its public IP.
-   **Self-Update Mechanism:** The Ansible playbook (`ansible/playbook.yml`) templates `ansible/templates/runme.sh.j2` to `/opt/rerun.sh`. This script, when executed, pulls the latest Ansible configuration from GCS and re-runs the playbook. A cron job is also set up by Ansible to execute `/opt/rerun.sh` every 5 minutes. This ensures the bastion's configuration (and potentially SFTPGo initial data if conditions for initialization are met) can be updated dynamically from changes pushed to the GCS bucket.

<a name="ftp-cluster-mig"></a>
### FTP Cluster (Managed Instance Group - MIG)
(Defined in `mig.tf`)
-   **Purpose:** Provides a scalable and highly available pool of FTP/SFTP server instances.
-   **Instance Template (`module "ftp_instance_template"`):**
    -   Machine Type: `var.machine_type_ftp` (default: `e2-standard-4`).
    -   Image: Ubuntu 20.04 LTS.
    -   Tags: `["ftp"]`.
    -   Service Account: Uses the shared FTP service account (`data.google_service_account.ftp.email`).
    -   Startup Script (`user-data`): Similar to the bastion host, it installs Ansible, copies playbooks from GCS, runs `rerun-pb.yml`, and executes `/opt/rerun.sh`. This process configures SFTPGo on each instance.
-   **Managed Instance Group (`module "ftp_mig"`):**
    -   Source: `terraform-google-modules/vm/google//modules/mig`.
    -   Region: `var.region`.
    -   `autoscaling_enabled = true`.
    -   `target_size = 3` (deploys 3 instances by default).
    -   Hostname prefix: `ftp` (e.g., `ftp-xxxx`).
    -   Health Check for MIG: An HTTP health check (`health_check_name = "mig-https-hc"`, though configuration shows type "http", path "/healthz", port 80) is defined for the MIG to assess instance health for auto-repair and autoscaling decisions. This is distinct from the load balancer's health check.
-   **Self-Update Mechanism:** Similar to the bastion, FTP instances in the MIG also have the cron job running `/opt/rerun.sh` every 5 minutes. This ensures their SFTPGo configurations stay synchronized with the definitions in GCS, applied via Ansible.

<a name="load-balancer"></a>
### Load Balancer
(Defined in `loadbalancer.tf`)
-   **Type:** A Google Cloud Regional TCP Network Load Balancer, configured using `google_compute_forwarding_rule` and `google_compute_region_backend_service`.
-   **Purpose:** Distributes incoming TCP traffic for FTP (port 21) and SFTP (port 2022, though `all_ports = "true"` on the forwarding rule means it will forward traffic for any port directed to its IP if not further restricted by backend service port specifications) to healthy instances in the `ftp-mig`. It is also crucial for enabling passive FTP data connections by presenting a stable external IP.
-   **Forwarding Rule (`google_compute_forwarding_rule.ftp`):**
    -   Name: `ftp-ip`.
    -   `all_ports = "true"`: Forwards traffic for all ports. The backend service then specifies which ports the instances are listening on.
    -   `load_balancing_scheme = "EXTERNAL"`.
    -   `ip_protocol = "TCP"`.
    -   `network_tier = "STANDARD"`.
-   **Backend Service (`google_compute_region_backend_service.ftp`):**
    -   Name: `ftp`.
    -   Protocol: `TCP`.
    -   `session_affinity = "CLIENT_IP"`: Ensures that packets from the same client IP address are consistently directed to the same backend instance. This is important for stateful protocols like FTP, especially during the multi-connection setup (control and data channels).
    -   Targets the instance group created by `module.ftp_mig.instance_group`.
-   **Health Check (`google_compute_region_health_check.ftp-check`):**
    -   A TCP health check specifically for the load balancer to determine the health of backend instances.
    -   Checks TCP connectivity on port `21` (the standard FTP command port) of the backend instances.
-   **DNS:** An 'A' record (e.g., `haftp.yourdomain.com`, derived from `var.dns_record_name_lb` and `var.dns_zone_value`) is created, pointing to the load balancer's external IP address.

<a name="storage-solutions"></a>
### Storage Solutions
-   **Cloud SQL (MySQL) (`database.tf`):**
    -   A `google_sql_database_instance` named `ftp-<random_id.db_name_suffix.hex>` is provisioned.
    -   Database version: `MYSQL_8_0`.
    -   Region: `var.region`.
    -   Tier: `db-n1-standard-1` (a small, general-purpose machine type).
    -   Authorized Networks: Configured with `0.0.0.0/0` and another specific IP ("2.230.193.19/32"), effectively allowing broad public access. This behavior is enabled because the `google_project_organization_policy.enable_sql_public` resource disables the `sql.restrictAuthorizedNetworks` constraint. For production, this should be restricted to the VPC or specific application IPs.
    -   A database named `ftp` and a user (default `sftpgo`, from `var.sqlusername`) are created. The password for this user is randomly generated by `random_password.dbpassword` and stored in Google Secret Manager.
    -   **Purpose:** This database stores all SFTPGo application metadata: user accounts, administrator accounts, groups, virtual folder definitions, permissions, API keys, and other settings. This centralization of metadata allows the SFTPGo instances in the MIG to be stateless.
-   **Cloud Storage (GCS) (`storage.tf`):**
    -   A `google_storage_bucket` named `ansible-${random_id.suffix.hex}` is created.
        -   Location: `var.bucket_zone` (default `US`).
        -   `uniform_bucket_level_access = true`.
        -   `force_destroy = true`: Allows Terraform to delete the bucket even if it contains objects.
    -   **Purpose 1 (Ansible Files):** All files from the local `./ansible/` and `./demo/` directories (e.g., `ansible/playbook.yml`, `demo/README.txt`) are uploaded as objects to this bucket by `google_storage_bucket_object` resources. Instances use `gsutil` in their startup scripts to download these files for their configuration.
    -   **Purpose 2 (SFTPGo Backend):** This GCS bucket (specifically the `demo/` path within it) is configured as a GCS backend for the `sftp_demo_user`'s `/gcs` virtual folder in SFTPGo. This demonstrates using GCS for user file storage.
-   **Filestore (NFS) (`storage.tf`):**
    -   A `google_filestore_instance` named `ftp` is created.
        -   Tier: `STANDARD`.
        -   Capacity: 1024 GB.
        -   File share name: `ftp` (defined in `file_shares { name = "ftp" }`).
        -   Network: `default` (connects to the default VPC network, making it accessible to instances in that network).
    -   **Purpose:** Provides a shared Network File System (NFS). It's mounted at `/opt/sftpgo/nfs` on the bastion host and all FTP instances by an Ansible task. This NFS share is configured as the backend for the `sftp_demo_user`'s `/nfs` virtual folder in SFTPGo, demonstrating shared file system storage.
    -   The NFS server's internal IP address and the share name are stored in Secret Manager for Ansible to retrieve during the mount process.

<a name="configuration-and-secrets-management"></a>
### Configuration and Secrets Management
-   **SFTPGo Configuration:**
    -   The primary runtime configuration for SFTPGo is defined in `/opt/sftpgo/sftpgo.json` on each instance. This file is generated by Ansible from the `ansible/templates/sftpgo.json.j2` Jinja2 template. This template is populated with dynamic values, many of which are fetched from Google Secret Manager (e.g., database credentials, Load Balancer IP for passive FTP).
    -   Initial data for SFTPGo, such as the first administrator user and the demo user (along with their virtual folders for GCS and NFS), is defined in `ansible/templates/sftp-init.json.j2`. SFTPGo uses this file to populate its database if it's empty upon first start (controlled by `SFTPGO_LOADDATA_MODE=0` in `docker-compose.yaml.j2`). This initialization is primarily driven by the bastion host's initial Ansible run. FTP instances in the MIG typically connect to an already initialized database.
-   **Ansible Automation (`ansible/` directory):**
    -   Ansible playbooks (`playbook.yml`, `rerun-pb.yml`), templates, and other related files are stored in the GCS bucket and fetched by instances at startup and periodically via a cron job.
    -   Ansible is responsible for a wide range of configuration tasks on each instance:
        -   Installing necessary software packages (Docker, Docker Compose, NFS client utilities, Python libraries, etc.).
        -   Creating required directory structures (e.g., `/opt/sftpgo` and its subdirectories).
        -   Fetching secrets from Google Secret Manager using `gcloud` commands.
        -   Templating and deploying SFTPGo configuration files (`sftpgo.json`, `sftp-init.json`, `docker-compose.yaml`).
        -   Mounting the NFS share from Filestore to `/opt/sftpgo/nfs`.
        -   Managing the SFTPGo Docker container (starting, restarting, ensuring it's running with the correct configuration).
        -   Setting up the cron job that executes `/opt/rerun.sh` for periodic self-updates of the configuration.
-   **Secret Manager (`secrets.tf`):**
    -   Terraform provisions multiple secrets in Google Secret Manager to securely store all sensitive information:
        -   `bucket_id`: The URL of the GCS bucket that holds the Ansible automation files (e.g., `gs://ansible-xxxx`).
        -   `sqlusername`, `sqlppass`, `sqlhost`: Credentials and connection information for the Cloud SQL database.
        -   `cookie_key`: A randomly generated hexadecimal string used by SFTPGo for securing session cookies.
        -   `nfs_server`, `nfs_server_mount`: The IP address of the Filestore instance and the name of its NFS share.
        -   `ftp_demo_user`, `ftp_demo_password` (stored as a bcrypt hash), `ftp_demo_pubkey`.
        -   `ftp_webadmin_user`, `ftp_webadmin_password` (stored as a bcrypt hash).
    -   The `ftp-service-account` (defined in `serviceaccount.tf` and assigned to both the bastion host and FTP instances) is granted the `roles/secretmanager.secretAccessor` IAM role for each of these secrets. This allows the instances running under this service account to read the secret values at runtime.
    -   Ansible scripts running on the instances use `gcloud secrets versions access latest --secret="<secret_name>"` commands to retrieve the plaintext values of these secrets, which are then injected into configuration files or used directly in setup tasks.

<a name="dns"></a>
### DNS
(Defined in `dns.tf`)
-   The solution includes optional DNS management capabilities through Google Cloud DNS.
-   **Conditional Creation:** A `google_dns_managed_zone` resource can be created if the `var.create_dns_zone` variable is set to `true`. If it's `false`, Terraform assumes an existing DNS zone (specified by `var.dns_zone_name`) resides in the project defined by `var.existing_dns_project_id`.
-   **DNS Records Created:**
    -   An 'A' record for the bastion host's public IP address. The hostname is formed by `var.dns_record_name_bastion` (e.g., `ftp`) prepended to `var.dns_zone_value` (e.g., `ftp.gcpdomain.`).
    -   An 'A' record for the Load Balancer's public IP address. The hostname is formed by `var.dns_record_name_lb` (e.g., `haftp`) prepended to `var.dns_zone_value`.
-   The `local.dns_project_id` variable dynamically determines the project ID for DNS operations based on whether a new zone is being created or an existing one is used.
-   If a new private DNS zone is created (`var.dns_zone_visibility == "private"`), it is associated with the VPC network (`google_compute_network.vpc_network.id`), making the DNS records resolvable only within that VPC.

---

## 4. Deployment

<a name="setup"></a>
### Setup
1.  **Clone Repository:** If you haven't already, clone the repository containing the Terraform and Ansible files to your local machine.
    ```bash
    # Example: git clone https://github.com/your-repo/gcp-ftp-cluster.git
    # cd gcp-ftp-cluster
    ```
2.  **Configure Variables (`variables.tf` or `terraform.tfvars`):**
    -   Open the `variables.tf` file and carefully review the default values. You will need to customize several of these to match your specific GCP environment and desired configuration.
    -   **Crucial variables that typically require changes:**
        -   `project_id`: Your target Google Cloud Project ID.
        -   `billing_account`: Your GCP Billing Account ID.
        -   `org_id` / `folder_id`: Specify if the project is to be created under a specific organization or folder (if applicable).
        -   `region` & `zone`: The desired GCP region and zone for resource deployment.
        -   `gcp_auth_file`: Path to your service account key JSON file if you are not using Application Default Credentials (default: `"./credentials.json"`).
        -   Credentials for SFTPGo: `sqlusername`, `ftp_demo_user`, `ftp_demo_password`, `ftp_webadmin_user`, `ftp_webadmin_password`. **It is highly recommended to change default passwords.**
        -   DNS settings: `create_dns_zone`, `dns_zone_name`, `dns_zone_value` (ensure this is a domain you control or can manage), and `existing_dns_project_id` if using an existing DNS zone.
    -   For sensitive values or environment-specific overrides that you don't want to commit to version control, it's best practice to create a `terraform.tfvars` file (this file is usually included in `.gitignore`). For example:
        ```terraform
        # terraform.tfvars
        project_id          = "my-gcp-project-123"
        billing_account     = "012345-6789AB-CDEF01"
        region              = "us-west1"
        zone                = "us-west1-a"
        ftp_demo_password   = "AVerySecurePassword123!"
        ftp_webadmin_password = "AnotherSecurePassword456!"
        dns_zone_value      = "ftp.mycompany.com."
        # ... other overrides
        ```
3.  **(Optional) Service Account Key for Terraform:** If you are using a service account key for Terraform to authenticate with GCP (as specified by `gcp_auth_file`), ensure the JSON key file is present at the defined path. Using Application Default Credentials (ADC) by authenticating `gcloud` is often preferred.

<a name="terraform-execution"></a>
### Terraform Execution
1.  **Initialize Terraform:** Navigate to the root directory of the cloned repository (where the main `.tf` files are located) in your terminal and run:
    ```bash
    terraform init
    ```
    This command initializes the working directory. It downloads the necessary provider plugins (like the Google Cloud provider) and sets up the backend (which is local by default).
2.  **Plan Deployment (Recommended):** Create an execution plan to preview the changes Terraform intends to make to your infrastructure:
    ```bash
    terraform plan -out=tfplan
    ```
    Review the output of this command carefully. It will show you which resources Terraform will create, modify, or destroy. The `-out=tfplan` option saves this plan to a file named `tfplan`.
3.  **Apply Configuration:** Execute the plan to provision the resources in your GCP project:
    ```bash
    terraform apply "tfplan"
    ```
    If you chose not to save the plan to a file in the previous step, you can run `terraform apply` directly. Terraform will then generate a plan, display it, and ask for your confirmation before proceeding.
    When prompted to confirm (`Do you want to perform these actions?`), type `yes` and press Enter.
    The deployment process can take several minutes as it involves creating various resources, including a Cloud SQL instance, a Filestore instance, and multiple Compute Engine instances.
4.  **Monitor Progress:** Observe the output in your terminal. Terraform will provide real-time updates as it creates each resource. If any errors occur, Terraform will halt and display error messages.
5.  **Review Outputs:** Upon successful completion, Terraform will display the values of any defined outputs (as specified in `output.tf`). These outputs include important information such as connection URLs and default credentials. It's advisable to note these down.

---

## 5. Configuration Details

<a name="terraform-variables"></a>
### Terraform Variables (`variables.tf`)
This file is central to customizing the deployment before running `terraform apply`. Below are some of the key variables and their significance:

-   **Project & Billing Configuration:**
    -   `project_id` (string): The ID of the Google Cloud Project where all resources will be deployed. Default: `"project-id-1234567890"`. **This must be changed to your actual project ID.**
    -   `project_name` (string): A descriptive name for the project if Terraform is also responsible for creating it via `module "project-services"`. Default: `"An FTP Project"`.
    -   `folder_id` (string): The ID of the GCP folder under which the project may be created. Default: `null`.
    -   `org_id` (string): The ID of the GCP organization under which the project may be created. Default: `"1234567890"`.
    -   `billing_account` (string): The ID of the billing account to link to the project. Default: `"Your Billing Account"`. **This must be changed to your actual billing account ID.**
-   **GCP Location Settings:**
    -   `region` (string): The GCP region for deploying most resources (e.g., Compute Engine instances, Cloud SQL). Default: `"us-central1"`.
    -   `zone` (string): The GCP zone within the specified region (e.g., for Filestore, bastion host). Default: `"us-central1-b"`.
    -   `bucket_zone` (string): The regional or multi-regional location for the GCS bucket that stores Ansible files. Default: `"US"`.
-   **Instance Sizing:**
    -   `machine_type_bastion` (string): Machine type for the bastion host. Default: `"e2-standard-4"`.
    -   `machine_type_ftp` (string): Machine type for FTP instances in the Managed Instance Group. Default: `"e2-standard-4"`.
-   **Authentication for Terraform:**
    -   `gcp_auth_file` (string): Path to the GCP service account key JSON file used by Terraform for authentication. Default: `"./credentials.json"`.
-   **Network Configuration:**
    -   `network_name` (string): Name of the VPC network to use or create. Default: `"default"`.
    -   `source_ranges` (list(string)): A list of IP CIDR ranges allowed by the `admin-firewall-in` rule (for SSH, Web UI access). Defaults include Google's health check and IAP ranges.
-   **Application Credentials (Important: Change default passwords for security):**
    -   `sqlusername` (string): Username for SFTPGo to connect to the Cloud SQL database. Default: `"sftpgo"`.
    -   `ftp_demo_user` (string): Username for the pre-configured SFTP/FTP demo user. Default: `"user"`.
    -   `ftp_demo_password` (string): Password for the demo user. Default: `"password"`. **Change this.**
    -   `ftp_demo_pubkey` (string): Public SSH key for the demo user (for SFTP public key authentication). Default: An example Ed25519 key.
    -   `ftp_webadmin_user` (string): Username for the SFTPGo web administration interface. Default: `"admin"`.
    -   `ftp_webadmin_password` (string): Password for the web admin user. Default: `"password"`. **Change this.**
-   **DNS Configuration (Optional):**
    -   `create_dns_zone` (bool): If `true`, Terraform attempts to create a new Cloud DNS managed zone. Default: `true`.
    -   `existing_dns_project_id` (string): The Project ID where an existing DNS zone resides if `create_dns_zone` is `false`. Default: `"existing_project_id"`.
    -   `dns_zone_name` (string): The name of the DNS managed zone (e.g., `mycompany-ftp-zone`). Default: `"myftp"`.
    -   `dns_zone_value` (string): The actual DNS suffix for the zone (e.g., `ftp.example.com.`). **Must end with a period.** Default: `"ftp.gcpdomain."`.
    -   `dns_record_name_bastion` (string): The subdomain part for the bastion host's 'A' record (e.g., `bastion`). Default: `"ftp"`.
    -   `dns_record_name_lb` (string): The subdomain part for the load balancer's 'A' record (e.g., `cluster`). Default: `"haftp"`.
    -   `dns_zone_visibility` (string): Visibility for a newly created zone (`"private"` or `"public"`). Default: `"private"`.

<a name="sftpgo-configuration"></a>
### SFTPGo Configuration
SFTPGo's behavior is primarily defined by two JSON files, which are dynamically generated by Ansible using Jinja2 templates. These templates are populated with values, many of which are securely retrieved from Google Secret Manager at runtime by the instances.

-   **`ansible/templates/sftpgo.json.j2` (becomes `/opt/sftpgo/sftpgo.json` on instances):**
    This is the main runtime configuration file for the SFTPGo server. Key sections include:
    -   **`common` section:** General settings like `idle_timeout`, `upload_mode`, etc.
    -   **`sftpd` section (SFTP Daemon):**
        -   `bindings`: Configures the SFTP service to listen on port `2022` at address `0.0.0.0` internally within the Docker container.
    -   **`ftpd` section (FTP Daemon):**
        -   `bindings`: Configures the FTP service.
            -   Port `2121` internally at address `0.0.0.0` (Docker maps this to port `21` on the host).
            -   `force_passive_ip`: This is dynamically set by Ansible to `{{ lb.stdout }}`, which resolves to the external IP address of the Network Load Balancer. This configuration is critical for passive FTP mode to work correctly when SFTPGo is behind NAT and a load balancer.
            -   `passive_port_range`: Set to `start: 50000`, `end: 50100`. These ports must be open on the instance firewalls and allowed through the Load Balancer.
        -   `disable_active_mode`: Set to `true`, as passive mode is generally preferred and more firewall-friendly for clients.
    -   **`data_provider` section (Database Configuration):**
        -   `driver`: `"mysql"`.
        -   `name`: `"ftp"` (the database name within the Cloud SQL instance).
        -   `host`: `{{sqlhost.stdout}}` (the IP address of the Cloud SQL instance, fetched from Secret Manager).
        -   `port`: `3306`.
        -   `username`: `{{sqluser.stdout}}` (the SQL username, fetched from Secret Manager).
        -   `password`: `{{sqlppass.stdout}}` (the SQL password, fetched from Secret Manager).
        -   `users_base_dir`: `"/srv/sftpgo/data"` (default local path on instances if local filesystem storage is used directly for a user's home directory).
    -   **`httpd` section (Web Admin & Client Interface):**
        -   `bindings`: Configures the web interface.
            -   Port `8080` internally (Docker maps this to port `80` on the host).
            -   `enable_web_admin` and `enable_web_client`: Both set to `true`.
        -   `signing_passphrase`: `{{ cookie_key.stdout }}` (a secret key fetched from Secret Manager, used by SFTPGo for session management and security).
-   **`ansible/templates/sftp-init.json.j2` (becomes `/opt/sftpgo/sftp-init.json` on instances):**
    This file is used by SFTPGo to perform an initial data load if the configured database is empty. This behavior is typically controlled by the `SFTPGO_LOADDATA_FROM` and `SFTPGO_LOADDATA_MODE` environment variables in the `docker-compose.yaml.j2` file (`SFTPGO_LOADDATA_MODE=0` means load if DB is empty). This initialization is primarily intended to be effective during the **bastion host's first Ansible run** to seed the database with initial users and admins. FTP instances in the MIG will generally connect to an already initialized database and thus might ignore this file or process an empty version of it.
    -   **`users` array:**
        -   Defines the demo SFTP/FTP user:
            -   `username`: `{{ftp_demo_user.stdout}}` (value from Secret Manager).
            -   `password`: `{{ftp_demo_password.stdout}}` (bcrypt hash of the password, from Secret Manager).
            -   `public_keys`: `["{{ftp_demo_pubkey.stdout}}"]` (public SSH key string, from Secret Manager).
            -   `home_dir`: `"/srv/sftpgo/data/{{ftp_demo_user.stdout}}"`.
            -   `virtual_folders`: Defines mappings to backend storage:
                -   **NFS Share:** A virtual folder named `nfs` with `virtual_path: "/nfs"`, mapped to the instance's local path `/nfs` (which is the mount point for the Filestore NFS share). Filesystem provider is `0` (local/mounted).
                -   **GCS Bucket:** A virtual folder named `gcs` with `virtual_path: "/gcs"`. Configured with `provider: 2` (GCS), GCS `bucket` name `{{bucket_id.stdout}}` (the GCS bucket used for Ansible files, fetched from Secret Manager), and `key_prefix: "demo/"`. It uses `automatic_credentials: 1`, meaning it will use the instance's service account for GCS access.
    -   **`admins` array:**
        -   Defines the initial web administrator user:
            -   `username`: `{{ftp_webadmin_user.stdout}}` (value from Secret Manager).
            -   `password`: `{{ftp_webadmin_password.stdout}}` (bcrypt hash of the password, from Secret Manager).
            -   `permissions`: `["*"]` (granting full administrative permissions).

<a name="ansible-automation"></a>
### Ansible Automation
Ansible is responsible for the detailed configuration of the bastion host and the FTP instances within the MIG after they are provisioned by Terraform. The core automation logic resides in `ansible/playbook.yml`.

-   **Execution Flow:**
    1.  **Instance Startup:** When a bastion or FTP instance is created by Terraform, its `user-data` (startup script specified in the instance template) executes. This script performs initial setup:
        -   Installs Ansible and other necessary packages (e.g., `expect`, Python libraries for Ansible modules).
        -   Downloads the contents of the `gs://<ansible-bucket-name>/ansible/` GCS path to a local directory (e.g., `/opt/ansible/`) on the instance using `gsutil cp -r ...`. This GCS bucket is the one created by Terraform to store the Ansible playbooks and templates.
        -   Executes the main Ansible playbook, typically `ansible-playbook /opt/ansible/rerun-pb.yml`.
    2.  **`rerun-pb.yml`:** This is a simple playbook that usually just includes the main `playbook.yml`. This structure might be for future flexibility or to separate initial run logic.
    3.  **Cron-based Updates:** The main `playbook.yml`, when executed, templates the `ansible/templates/runme.sh.j2` script to `/opt/rerun.sh` on the instance. It also sets up a cron job that executes `/opt/rerun.sh` at regular intervals (e.g., every 5 minutes).
    4.  **`/opt/rerun.sh`:** This shell script essentially repeats step 1 (gsutil copy of Ansible files from GCS) and step 2 (ansible-playbook execution). This creates a continuous configuration update loop, allowing changes made to the Ansible files in the GCS bucket to be automatically rolled out to all instances without requiring instance recreation.
-   **Key Tasks Performed by `ansible/playbook.yml`:**
    -   **Package Installation:** Ensures that all necessary software packages are installed on the instances. This includes `python3-pymysql` (for SFTPGo to connect to MySQL), `docker`, `docker-compose` (for running SFTPGo), `nfs-common` (for mounting Filestore), `jq` (for JSON processing), `expect`, etc. Some installations are conditional (e.g., run only if `/opt/sftpgo` directory doesn't exist, implying an initial setup).
    -   **Directory Creation:** Creates the necessary directory structure for SFTPGo, such as `/opt/sftpgo`, `/opt/sftpgo/home`, `/opt/sftpgo/data`, and `/opt/sftpgo/nfs` (the NFS mount point).
    -   **Secret Retrieval:** Uses `shell` module tasks with `gcloud secrets versions access latest --secret="<secret-name>"` commands to fetch various secrets (SQL credentials, Load Balancer IP, NFS details, user credentials, GCS bucket ID, SFTPGo cookie key) from Google Secret Manager. The output of these commands is registered as Ansible variables.
    -   **Template Rendering:** Populates Jinja2 templates (e.g., `sftpgo.json.j2`, `sftp-init.json.j2`, `docker-compose.yaml.j2`, `runme.sh.j2`) with the retrieved secrets and other dynamic data (like instance tags). The rendered files are then deployed to their target paths on the instance (e.g., `/opt/sftpgo/sftpgo.json`).
    -   **NFS Mount:** Uses the `ansible.posix.mount` module to mount the Google Filestore NFS share (using server IP and share name fetched from secrets) to the local `/opt/sftpgo/nfs` directory. It also creates a `README.txt` file on the NFS share to indicate successful mounting.
    -   **Docker Compose Management:** Uses a `shell` command `docker-compose -f {{ workdir }}/docker-compose.yaml up -d` to start or update the `sftpgo` service defined in the rendered `/opt/sftpgo/docker-compose.yaml` file. The `-d` flag runs the container in detached mode.
    -   **Database Initialization Wait (Conditional for FTP nodes):** For instances tagged `ftp` (i.e., the MIG nodes), there's a task using `community.mysql.mysql_query` that waits until the `ftp` database in Cloud SQL is initialized. It does this by repeatedly executing `show tables;` and checking if the number of tables is greater than a certain threshold. This prevents FTP nodes from starting SFTPGo prematurely if the bastion host hasn't yet seeded the database with initial data.
-   **Conditional Logic and Targeting:** The playbook uses Ansible tags (`always`, `ftp`, `bastion`) and `when` conditions to control which tasks run on which instances or under what circumstances. For example, the `sftp-init.json` file is populated with user and admin data primarily on the bastion host for initial database seeding, while FTP nodes might receive an empty version as they expect the database to be ready.

<a name="secret-management"></a>
### Secret Management
Secure handling of sensitive data is a critical aspect of this deployment, primarily managed through Google Secret Manager and orchestrated by Terraform.

-   **Secret Creation by Terraform (`secrets.tf`):**
    -   Terraform defines `google_secret_manager_secret` resources to create the secret "containers" in Secret Manager for each piece of sensitive information.
    -   `google_secret_manager_secret_version` resources are then used to populate these secrets with their actual values.
    -   **Types of information stored as secrets include:**
        -   `bucket_id`: The URL of the GCS bucket that stores the Ansible automation files (e.g., `gs://ansible-xxxx`).
        -   `sqlusername`: The username for the Cloud SQL database connection.
        -   `sqlppass`: The randomly generated password for the Cloud SQL user.
        -   `sqlhost`: The IP address of the Cloud SQL instance.
        -   `cookie_key`: A randomly generated hexadecimal string used by SFTPGo for signing session cookies, enhancing web UI security.
        -   `nfs_server`: The IP address of the Google Filestore instance (NFS server).
        -   `nfs_server_mount`: The name of the share on the Filestore instance (e.g., `ftp`).
        -   `ftp_demo_user`: The username for the demo SFTP/FTP user.
        -   `ftp_demo_password`: The bcrypt hash of the demo FTP user's password. Terraform computes this hash from the plaintext password provided in `variables.tf` using the `bcrypt()` function available through a provider or module.
        -   `ftp_demo_pubkey`: The public SSH key string for the demo user.
        -   `ftp_webadmin_user`: The username for the SFTPGo web administration interface.
        -   `ftp_webadmin_password`: The bcrypt hash of the web admin user's password, also computed by Terraform.
-   **Access Control for Secrets:**
    -   The `ftp-service-account` (defined in `serviceaccount.tf` and assigned as the service account for both the bastion host and the FTP instances in the MIG) is granted the `roles/secretmanager.secretAccessor` IAM role for each individual secret. This permission allows processes running under this service account on the instances to read the secret values.
-   **Consumption of Secrets by Ansible:**
    -   Ansible tasks within the `playbook.yml` (running on the instances) use `shell` module commands like:
        `gcloud secrets versions access latest --secret="<secret-name>"`
        to retrieve the plaintext content of the secrets from Secret Manager.
    -   The output of these commands (the secret values) is then registered into Ansible variables.
    -   These Ansible variables are subsequently used to populate Jinja2 templates for configuration files (e.g., injecting database passwords into `sftpgo.json`, or user credentials into `sftp-init.json`) or used directly in other Ansible tasks (like configuring the NFS mount).

This layered approach ensures that sensitive data is not hardcoded directly in Terraform configurations or Ansible playbooks that might be stored in version control. Instead, secrets are securely stored in Secret Manager, and access is tightly controlled via IAM, with instances retrieving them only when needed at runtime.

---

## 6. Usage

Once the Terraform deployment has successfully completed, you can access the FTP/SFTP services and the SFTPGo administrative web interface.

<a name="accessing-ftpsftp-service"></a>
### Accessing FTP/SFTP Service
-   **Endpoint for High Availability (Recommended):** Use the DNS name created for the Load Balancer. This hostname is provided in the `zz-instructions` Terraform output (e.g., `haftp.yourdomain.com`). Connecting to this endpoint ensures your traffic is distributed to one of the available healthy FTP instances in the Managed Instance Group.
-   **Endpoint for Bastion Host (Single Node, for Testing/Admin):** You can also connect directly to the bastion host's DNS name (e.g., `ftp.yourdomain.com`, also from `zz-instructions`). This is useful for testing individual node behavior or specific administrative tasks but does not offer high availability.
-   **Supported Protocols & Ports:**
    -   **SFTP (SSH File Transfer Protocol):** Connect to port `2022` (as configured in `sftpgo.json` and exposed by the Docker container on instances).
    -   **FTP (File Transfer Protocol) / FTPS (FTP over SSL/TLS):** Connect to port `21`. SFTPGo listens on port `2121` internally within the Docker container, which is then mapped to port `21` on the host instance by Docker.
        -   The current default setup configures plain FTP. For FTPS, you would need to configure TLS certificates within `sftpgo.json` (specifying certificate and key file paths) and ensure these certificate files are available to the SFTPGo container. Firewall rules might also need adjustment if different ports are used for implicit FTPS (port 990).
-   **User Credentials:**
    -   Use the pre-configured demo user credentials:
        -   Username: The value of `var.ftp_demo_user` (default: `user`).
        -   Password: The value of `var.ftp_demo_password` (default: `password`).
    -   **Public Key Authentication for SFTP:** If you provided a valid public SSH key in the `var.ftp_demo_pubkey` variable, you can authenticate as the demo user for SFTP connections using the corresponding private key, instead of or in addition to password authentication.
-   **FTP Passive Mode:** The deployment is configured for FTP passive mode. SFTPGo is set up with `force_passive_ip` pointing to the Load Balancer's IP address, which is crucial for ensuring that data connections for passive FTP can be correctly established when clients are behind NAT firewalls and connecting through the load balancer. The passive port range `50000-50100` is also configured.
-   **Virtual Folders for Demo User:**
    -   When connected as the demo user, you will have access to pre-defined virtual folders that map to different storage backends:
        -   `/gcs`: This virtual folder is mapped to the `demo/` prefix within the GCS bucket originally created for Ansible files (`ansible-<random_suffix>`). Files uploaded to or downloaded from `/gcs` will interact directly with this GCS location.
        -   `/nfs`: This virtual folder is mapped to the root of the shared Google Filestore NFS volume. Files in this folder are stored on the NFS share, making them accessible and consistent across all FTP instances and the bastion host (as they all mount this share).
        -   The user's actual home directory (defined by `home_dir` in `sftp-init.json`, typically `/srv/sftpgo/data/user` on the instance's local filesystem if not otherwise specified as a virtual mapping) is also available.

<a name="accessing-sftpgo-admin-web-ui"></a>
### Accessing SFTPGo Admin Web UI
-   **URL:** `http://<load_balancer_dns_name>/web/admin/login`
    -   For example: `http://haftp.yourdomain.com/web/admin/login` (the exact hostname will be in the `zz-instructions` Terraform output). The SFTPGo web UI is served on port `80` through the Load Balancer (internally, SFTPGo listens on `8080`, which Docker maps to `80`).
-   **Credentials:**
    -   Username: The value of `var.ftp_webadmin_user` (default: `admin`).
    -   Password: The value of `var.ftp_webadmin_password` (default: `password`).
-   **Functionality:** The SFTPGo web administration interface provides a comprehensive set of tools for managing the FTP/SFTP server, including:
    -   Managing users: Adding new users, deleting users, modifying passwords, setting permissions, defining quotas, configuring two-factor authentication.
    -   Managing administrator accounts.
    -   Defining and managing virtual folders and their mappings to various storage backends (GCS, S3, local, NFS via local mount point, etc.).
    -   Configuring server settings (though many core settings are managed by `sftpgo.json` which is controlled by Ansible in this setup).
    -   Viewing server logs and monitoring active connections.
    -   Creating data retention policies, event-triggered actions (e.g., run a script on upload), and more advanced features.

<a name="accessing-the-bastion-host"></a>
### Accessing the Bastion Host
-   **Endpoint:** Use the DNS name created for the bastion host (e.g., `ftp.yourdomain.com`, from the `zz-instructions` Terraform output) or its public IP address (available from the `output.bastion` Terraform output).
-   **Method:** Secure Shell (SSH) is the typical method for accessing the bastion host.
    -   **Direct SSH (if firewall permits):** If your source IP address is permitted by the `admin-firewall-in` rule (which allows SSH from `var.source_ranges`):
        ```bash
        ssh your_gcp_user@<bastion_dns_name_or_ip>
        ```
        (Replace `your_gcp_user` with a username that exists on the bastion host's OS, or use OS Login if it's enabled on the instance/project).
    -   **Using `gcloud compute ssh` (Recommended for ease of use and potential IAP integration):**
        ```bash
        gcloud compute ssh bastion-001 --project <your_project_id> --zone <your_zone>
        ```
        This command simplifies SSH access. If Identity-Aware Proxy (IAP) for TCP forwarding is configured for your project and instances, `gcloud compute ssh` can use it to provide a more secure connection method that doesn't require the bastion host to have a public IP address or broadly open firewall rules for SSH.
-   **Purpose of Bastion Access:** The bastion host can be used for:
    -   Manual execution of Ansible playbooks (e.g., `sudo ansible-playbook /opt/ansible/playbook.yml`) for immediate configuration updates or troubleshooting specific Ansible tasks.
    -   Directly inspecting logs on the bastion itself (e.g., `/opt/last.out` for Ansible execution, Docker logs if SFTPGo was run there for testing).
    -   Accessing other internal resources within the VPC network if necessary for administrative tasks.
    -   Debugging instance startup or configuration issues.

---

## 7. Troubleshooting

<a name="common-deployment-issues"></a>
### Common Deployment Issues
-   **API Eventual Consistency Errors (Referenced in `README.md` "Known Problems/Bugs"):**
    -   During `terraform apply`, you might encounter errors indicating that a resource could not be created or found, or that a permission was denied, even though a preceding step (like project creation or API enablement) should have set things up correctly. Examples from the README include:
        -   `Error: Error, failed to create instance ftp-INSTANCE: googleapi: Error 400: Invalid request: Organization Policy check failure...`
        -   `Error: Error creating Secret: googleapi: Error 403: Permission denied on resource project...`
        -   `Error: Unable to verify whether custom project role ... already exists...`
        -   `Error: Error creating instance: googleapi: Error 412: Constraint constraints/compute.vmExternalIpAccess violated...`
    -   **Cause:** Google Cloud APIs sometimes exhibit eventual consistency, meaning changes made (like enabling an API, setting an IAM policy, or creating a resource) might take a short while to fully propagate and become visible across all GCP systems and regions. Terraform, moving quickly, might attempt to create a dependent resource before the underlying change is globally consistent.
    -   **Solution:** As the `README.md` suggests, the primary workaround is often to "just wait 30 seconds and relaunch the apply. It should go right after." In some Terraform configurations, explicit `time_sleep` resources can be added between problematic steps, but this project relies more on implicit dependencies and retries.
-   **IAM Permission Denials:**
    -   If Terraform fails with errors like "Permission denied" or "forbidden", it indicates that the identity (user or service account) running `terraform apply` lacks the necessary IAM roles.
    -   **Solution:** Ensure the identity has all the roles listed in the [Prerequisites](#2-prerequisites) section, applied at the correct scope (GCP project, folder, or organization). Pay special attention to roles required for:
        -   Creating projects (if Terraform does this).
        -   Enabling service APIs (`roles/serviceusage.serviceUsageAdmin`).
        -   Managing IAM policies (`roles/resourcemanager.projectIamAdmin` or more specific roles like `roles/iam.serviceAccountAdmin`).
        -   Creating and managing specific resources like Compute Engine instances, Cloud SQL, Filestore, GCS buckets, Secret Manager secrets, and Cloud DNS zones.
-   **Resource Quotas Exceeded:**
    -   Deployments, particularly in new GCP projects or regions, might encounter resource quotas (e.g., limits on the number of vCPUs, external IP addresses, Filestore instances, Cloud SQL instances per region).
    -   **Solution:** Check the "Quotas" page in the GCP Console for your project. Identify the exceeded quota and request an increase from Google Cloud Support if necessary.
-   **Invalid Terraform Variable Values:**
    -   Typos, incorrect formats (e.g., for billing account ID, project ID), or logically invalid values (e.g., referencing a non-existent folder ID) in `variables.tf` or your `.tfvars` file can cause `terraform plan` or `terraform apply` to fail.
    -   **Solution:** Carefully review your variable definitions and the values you've provided, ensuring they match GCP requirements and your environment.
-   **Service API Not Enabled:**
    -   Terraform attempts to enable all necessary GCP service APIs via the `module "project-services"` using the `activate_apis` list. However, if the identity running Terraform lacks the `roles/serviceusage.serviceUsageAdmin` permission, this API enablement step might fail silently or explicitly. Subsequent attempts to create resources for those services will then fail.
    -   **Solution:** Either grant the `serviceusage.serviceUsageAdmin` role to the Terraform identity or pre-enable the required APIs in the GCP Console for your project. These include Compute Engine API, Cloud SQL Admin API, Secret Manager API, IAM API, Filestore API, Cloud DNS API, and others listed in `main.tf`.

<a name="checking-logs"></a>
### Checking Logs
Effective troubleshooting often involves inspecting logs from various components of the system.

-   **Terraform Logs:** The output in your console during `terraform plan` and `terraform apply` provides detailed information about the actions Terraform is taking, the state of resources, and any errors encountered. Increase verbosity with `TF_LOG=DEBUG terraform apply` for more detailed logs.
-   **Instance Startup Scripts (Cloud-Init Logs):**
    -   SSH into an instance (either the bastion host or one of トthe FTP MIG instances).
    -   Check the cloud-init logs for output from the `user-data` startup script:
        ```bash
        sudo cat /var/log/cloud-init-output.log
        ```
        This log will show package installation progress, `gsutil` commands, and the initial execution of Ansible.
-   **Ansible Logs:**
    -   The `runme.sh` script (which is executed by cron and at startup to run Ansible) redirects its standard output and standard error to `/opt/last.out` on the instances. This file is crucial for debugging Ansible playbook execution.
        ```bash
        sudo tail -f /opt/last.out  # To follow the log in real-time
        sudo less /opt/last.out     # To page through the log
        ```
-   **SFTPGo Docker Container Logs:**
    -   SSH into an FTP instance (or the bastion if you are testing SFTPGo there).
    -   First, list running Docker containers to get the container ID or name (it's typically named `sftpgo` as per `docker-compose.yaml.j2`):
        ```bash
        sudo docker ps
        ```
    -   Then, view the logs for the SFTPGo container:
        ```bash
        sudo docker logs sftpgo  # Or use the container ID
        ```
        Add the `-f` flag (`sudo docker logs -f sftpgo`) to follow the logs in real-time. These logs contain detailed information about SFTPGo's operations, user connections, errors, etc.
-   **Google Cloud Service Logs (via Cloud Logging):**
    -   **Cloud SQL:** Instance logs (MySQL errors, slow queries) can be viewed in the GCP Console: Navigate to SQL > Instances > select your instance > "Logs" tab.
    -   **Load Balancer:** Logs for the Network Load Balancer can be found in Cloud Logging. Go to Logging > Logs Explorer. You can filter by resource type, such as "TCP/SSL Proxy" or "Network Load Balancer" (the exact name might vary based on how GCP categorizes it).
    -   **Compute Engine:** Instance serial console output, system logs, and other logs are available in the GCP Console under Compute Engine > VM Instances > select your instance > "Logs" or "Serial port 1 (console)".
    -   **Filestore:** Check for any relevant logs or events in the Filestore section of the GCP Console.

<a name="service-health"></a>
### Service Health
Verifying the health status of different components can help pinpoint issues.

-   **Load Balancer Health Checks:**
    -   In the GCP Console, navigate to Networking > Network services > Load balancing.
    -   Select your load balancer (named `ftp-ip`).
    -   Examine the backend service (`ftp`) associated with it. The console will show the health status of each instance in the MIG as determined by the load balancer's health check (`ftp-check`, which is a TCP check on port 21).
-   **Managed Instance Group (MIG) Health:**
    -   In the GCP Console, go to Compute Engine > Instance groups.
    -   Select your MIG (named `ftp-mig` or similar).
    -   The MIG uses its own health check (defined as `health_check_name = "mig-https-hc"`, which is an HTTP check on port 80 looking for `/healthz`) to determine instance health for auto-repair and autoscaling purposes. The status of instances within the MIG (e.g., "RUNNING", "REPAIRING") will be displayed here.
-   **SFTPGo Admin Web UI:**
    -   If accessible, the SFTPGo web admin interface often has a status page or a section for viewing server logs and active connections, which can provide insights into the application's operational health.
-   **Basic Connectivity Tests:**
    -   Attempt to connect to the FTP/SFTP service using a standard client (like FileZilla, `sftp` command-line) targeting the load balancer's DNS name.
    -   Use `ping` or `nslookup` to verify that the DNS names for the load balancer and bastion host are resolving correctly to their respective IP addresses.
    -   From within an instance (e.g., the bastion host), try to connect to the Cloud SQL database using `mysql-client` to verify database connectivity if you suspect issues there.

---

## 8. Terraform Outputs
After a successful `terraform apply`, Terraform will print several output values that are defined in the `output.tf` file. These outputs provide quick access to important information and endpoints for your deployed infrastructure.

-   **`zz-instructions` (Marked as Sensitive):** This is a multi-line string output that consolidates key access details for convenience:
    ```
    # Example Output:
    zz-instructions = <<EOT
    Admin interface: http://haftp.ftp.example.com/web/admin/login
    Admin User: admin
    Admin Password: YourAdminPassword
    FTP Single: ftp://ftp.ftp.example.com
    FTP HA: ftp://haftp.ftp.example.com
    FTP User: user
    FTP Password: YourUserPassword
    Everything is also accessible via SFTP
    EOT
    ```
    *(Actual DNS names and credentials will be substituted with the values from your deployment.)*
    This output tells you:
    -   The URL for the SFTPGo Admin Web UI.
    -   The default web admin username and password.
    -   The FTP URL for connecting directly to the bastion host (single node, not highly available).
    -   The FTP URL for connecting to the High Availability service via the Load Balancer.
    -   The default demo FTP username and password.
-   **`bastion` (Marked as Sensitive):** The public IP address assigned to the bastion host instance.
    ```
    # Example Output:
    bastion = "34.x.x.x"
    ```
-   **`nfs` (Marked as Sensitive):** Provides detailed information about the Google Filestore instance object, typically a map of its attributes.
-   **`nfs_ip` (Marked as Sensitive):** The internal IP address of the Google Filestore (NFS server) instance within your VPC.
    ```
    # Example Output:
    nfs_ip = "10.x.x.x"
    ```
-   **`nfs_mountpoint` (Marked as Sensitive):** The name of the file share on the Filestore instance that is mounted by your VMs (e.g., `ftp`).
    ```
    # Example Output:
    nfs_mountpoint = "ftp"
    ```
-   **`project-id` (Marked as Sensitive):** The full ID of the Google Cloud project where the resources were deployed (e.g., `project-id-1234567890-ab`, where `-ab` is the `random_id.project.hex`).
    ```
    # Example Output:
    project-id = "Project ID: my-actual-project-id-xy"
    ```
-   **`me`:** The email address of the Google Cloud identity (user or service account) that executed the Terraform deployment. This is retrieved using `data "google_client_openid_userinfo" "me"`.
    ```
    # Example Output:
    me = "Operating as: user@example.com"
    ```

You can also retrieve these output values at any time after deployment (as long as the Terraform state file is accessible) by running `terraform output` in the same directory where you ran `terraform apply`. To see a specific output value, use `terraform output <output_name>`. For sensitive outputs, Terraform will indicate that their values are suppressed unless you use the `-json` flag or directly query the state.

---

## 9. Cleanup

To remove all resources created by this Terraform deployment from your Google Cloud Project and avoid ongoing charges, follow these steps carefully:

1.  **Navigate to Terraform Directory:** Open your terminal and ensure you are in the same directory where your Terraform configuration files (`.tf` files) are located and where you previously ran `terraform apply`.
2.  **Run `terraform destroy`:** Execute the following command:
    ```bash
    terraform destroy
    ```
    Terraform will:
    -   Read your current configuration.
    -   Consult the Terraform state file (usually `terraform.tfstate` if using a local backend) to identify all resources it currently manages.
    -   Present a plan detailing all the resources that will be destroyed.
3.  **Confirm Destruction:** Review the destruction plan very carefully. Ensure that only the resources you intend to remove are listed. If you are certain you want to proceed, Terraform will prompt you for confirmation:
    ```
    Do you really want to destroy all resources?
      Terraform will destroy all your managed infrastructure, as shown above.
      There is no undo. Only 'yes' will be accepted to confirm.

      Enter a value:
    ```
    Type `yes` and press Enter.

    This process will begin deleting all the resources managed by this Terraform configuration, which includes (but is not limited to):
    -   Compute Engine instances (bastion host, all instances in the MIG).
    -   Managed Instance Group (MIG) and associated Instance Templates.
    -   Network Load Balancer (forwarding rule, backend service, health check).
    -   Cloud SQL instance and its database.
    -   Google Filestore instance.
    -   Google Cloud Storage bucket created for Ansible files (including all objects within it, as `force_destroy = true` is set on the bucket resource).
    -   Secrets stored in Google Secret Manager.
    -   Custom IAM roles and IAM policy bindings created by Terraform.
    -   Cloud DNS records and the managed zone itself (if it was created by Terraform).
    -   VPC network components if they were specifically created by this configuration (though this setup often uses the 'default' VPC network, which would not be deleted unless the project itself is deleted).
4.  **`cleanup.sh` Script:** The repository includes a `cleanup.sh` script.
    -   **Typical Content:** This script is often a simple wrapper around the `terraform destroy` command, possibly with the `--auto-approve` flag to bypass the manual confirmation step.
        ```bash
        #!/bin/bash
        terraform destroy --auto-approve
        ```
    -   **Usage:** You can execute this script as an alternative to manually typing the `terraform destroy` command:
        ```bash
        ./cleanup.sh
        ```
    -   **Caution:** Be extremely careful when using `--auto-approve` in any script, especially with `terraform destroy`. Ensure you fully understand what resources will be deleted before running such a script.
5.  **Manual Verification (Highly Recommended):**
    -   After the `terraform destroy` command completes (which may take several minutes), it is a very good practice to log in to the Google Cloud Console.
    -   Manually navigate to the relevant sections (Compute Engine, Cloud SQL, Filestore, VPC Network, Load Balancing, IAM, Secret Manager, Cloud DNS, Cloud Storage) to verify that all associated resources have indeed been deleted.
    -   Occasionally, due to complex dependencies or transient GCP issues, a resource might not delete cleanly via Terraform. Manual verification helps catch these "straggler" resources, which you might then need to delete manually via the console or `gcloud` commands.

**Important Considerations Before Cleanup:**
-   **Data Loss:** Executing `terraform destroy` will permanently delete the Cloud SQL database instance and the Google Filestore instance. This means **any data stored within the SFTPGo database or on the NFS share will be irretrievably lost.** If you need to preserve any of this data, ensure you have performed adequate backups *before* running the destroy command.
-   **Project Deletion:** If your Terraform configuration (specifically, `module "project-services"`) was responsible for creating the GCP project itself, destroying the `google_project` resource managed by that module would initiate the deletion of the entire GCP project. This would remove *all* resources within that project, regardless of whether they were managed by this specific Terraform configuration or created through other means. Be absolutely certain of the scope if project creation was part of your Terraform setup.

---

## 10. Customization

This GCP FTP Cluster solution provides a robust and scalable foundation. However, you may want to adapt or extend it to meet more specific requirements. Here are some common areas for customization:

-   **Instance Sizing and Types:**
    -   Modify the `machine_type_bastion` and `machine_type_ftp` input variables in your `terraform.tfvars` file or directly in `variables.tf` to choose different GCP machine types. This can be done to allocate more CPU or memory for higher performance, or to select more cost-effective types for development or low-traffic environments.
    -   Consider using preemptible VMs for the FTP instances in non-critical or development environments to significantly reduce costs, though this would require adjustments to the instance template configuration and an understanding of the implications of preemption.
-   **SFTPGo Features and Detailed Configuration:**
    -   Edit the Ansible template `ansible/templates/sftpgo.json.j2` to fine-tune a wide array of SFTPGo settings:
        -   Enable or disable protocols (e.g., WebDAV is configured but its bindings are set to port 0, effectively disabling it by default).
        -   Change default port numbers for services (remember to update Docker port mappings in `ansible/templates/docker-compose.yaml.j2` and corresponding firewall rules in `firewall.tf`).
        -   Configure TLS/SSL for FTP (FTPS) by specifying certificate paths within `sftpgo.json`. This would also involve managing the deployment of these certificate files to the instances and ensuring SFTPGo can access them.
        -   Adjust security policies such as idle timeouts, Multi-Factor Authentication (MFA) requirements for users/admins, password policies, and IP whitelisting/blacklisting.
        -   Set up event handlers for actions like file uploads/downloads (e.g., trigger a Cloud Function or send a notification).
    -   After modifying Ansible templates, upload them to the GCS bucket used by the instances. The cron-based update mechanism on the instances should then pick up these changes. For more controlled rollouts, consider integrating with a CI/CD pipeline.
-   **User Management Strategies:**
    -   **SFTPGo Admin UI:** For ongoing user management (adding, removing, or modifying users, groups, permissions, and quotas) after the initial deployment, the SFTPGo web admin interface is the most straightforward method.
    -   **`ansible/templates/sftp-init.json.j2`:** This file is suitable for defining the initial set of users and admins during the first deployment (when the database is empty). Modifying it for existing deployments requires careful consideration of SFTPGo's `SFTPGO_LOADDATA_MODE` setting, as it might not re-apply data if the database is already populated. For declarative, ongoing user management via code, consider using SFTPGo's REST API.
-   **Alternative Storage Backends for SFTPGo:**
    -   SFTPGo supports a variety of storage backends beyond GCS and NFS (via local mount). These include S3-compatible object storage, Azure Blob Storage, local instance filesystems, and encrypted storage layers.
    -   You can configure new virtual folders or modify existing ones to use these alternative backends. This is typically done via the SFTPGo Admin UI or by directly editing the `filesystem` configuration within the `sftpgo.json` file (managed by Ansible).
-   **Firewall Rule Adjustments:**
    -   Modify the firewall rules defined in `firewall.tf` to implement stricter source IP filtering (e.g., allowing access only from your corporate network) or to open/close additional ports as required by your specific use cases or integrated services.
-   **Autoscaling Parameters for the MIG:**
    -   Adjust the Managed Instance Group settings in `mig.tf`:
        -   Change `target_size` for a different static number of FTP instances.
        -   Implement more sophisticated autoscaling by setting `min_replicas`, `max_replicas`, and defining autoscaling policies based on metrics like CPU utilization, network traffic, or custom Cloud Monitoring metrics.
-   **Backup and Recovery Strategy:**
    -   **Cloud SQL:** While GCP provides some default backup capabilities, you should explicitly configure automated backups and point-in-time recovery (PITR) for the MySQL instance through the GCP Console or by adding relevant Terraform resources (e.g., `google_sql_database_instance` backup configuration).
    -   **Filestore:** Google Filestore offers snapshot capabilities for creating backups of your NFS share. Plan and automate these snapshots as needed.
    -   **SFTPGo Configuration Data:** SFTPGo itself has a backup feature (accessible via its REST API or the web UI) that can export its configuration (users, folders, settings, etc.) as a JSON file. Consider automating this process and storing the backup securely (e.g., in a versioned GCS bucket).
-   **Enhanced Monitoring and Logging:**
    -   Integrate with Cloud Monitoring to collect and visualize more detailed metrics from your Compute Engine instances and the SFTPGo application itself (SFTPGo can expose Prometheus metrics).
    -   Configure log shipping from the Docker containers running SFTPGo to Cloud Logging for centralized analysis, alerting, and long-term retention.
-   **Security Hardening Measures:**
    -   Implement more granular IAM policies based on the principle of least privilege for all service accounts and users.
    -   Regularly update the base VM images and all installed software packages on the instances to patch vulnerabilities.
    -   Apply OS-level security hardening configurations on the Compute Engine instances.
    -   Consider using Identity-Aware Proxy (IAP) for SSH access to instances instead of relying solely on public IP addresses and firewall rules, for enhanced security.
-   **TLS Certificate Management for Web UI/FTPS:**
    -   If you enable HTTPS for the SFTPGo web admin interface or FTPS, automate the provisioning and renewal of TLS certificates (e.g., using Let's Encrypt with a DNS challenge, or by integrating with Google Certificate Manager).
-   **CI/CD Pipeline Integration:**
    -   For robust and automated management, integrate the Terraform and Ansible configurations into a Continuous Integration/Continuous Deployment (CI/CD) pipeline (e.g., using Cloud Build, Jenkins, GitLab CI, GitHub Actions).
        -   Store the Terraform state file in a remote backend like a GCS bucket for team collaboration and state locking.
        -   Manage Ansible playbooks and templates in a version-controlled repository (e.g., Git) and automate their upload to the designated GCS bucket as part of the deployment pipeline.
        -   Implement automated testing for your infrastructure and configuration changes.
