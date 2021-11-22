# FTP loadbalanced Demo

### Features

- Grant correct Roles to the service account being used 
- Set Policy at project level to enable IP and other limitations
- Create The project in a specific region/zone
- Link the project to the correct Billing
- Configure the network using NAT for the navigation (reducing costs)
- Configure the Firewall
- Create a Service account with the correct roles
- Create a Mysql Database and credentials
- Create a gs Bucket
- Create a Bastion host
- Create a template for the FTP host
- Create a Managed (Regional) Instance Group for the FTP hosts
- Create a Network Loadbalancer TCP
- Install sftpgo via ansible on docker
- Put all the sensible informations into secrets to prevent data leak
- Configure sftpgo to work as passive FTP (most used way)
- Use gsBucket as common storage interface thanks to sftpgo

### Todo

- Write an API call-out to configure the inner part of sftpgo
- Create FileStore to produce a common datastore instead of gsBucket (to prove alternative way to customer)
- Manage a DNS zone to provide a user readable access

### Known Problems/Bugs

- Due to the API being faster to say "done" than the actual "done state" you could encounter errors as such:
  ```
  ╷
  │ Error: Error, failed to create instance ftp-INSTANCE: googleapi: Error 400: Invalid request: Organization Policy check failure: the authorized networks of this instance violates the constraints/sql.restrictAuthorizedNetworks enforced at the 0123456789 project.., invalid
  │
  │   with google_sql_database_instance.ftp,
  │   on database.tf line 10, in resource "google_sql_database_instance" "ftp":
  │   10: resource "google_sql_database_instance" "ftp" {
  │
  ╵
  ╷
  │ Error: Error creating Secret: googleapi: Error 403: Permission denied on resource project myproject-XXXX.
  │ Details:
  │ [
  │   {
  │     "@type": "type.googleapis.com/google.rpc.Help",
  │     "links": [
  │       {
  │         "description": "Google developer console API key",
  │         "url": "https://console.developers.google.com/project/myproject-XXXX/apiui/credential"
  │       }
  │     ]
  │   },
  │   {
  │     "@type": "type.googleapis.com/google.rpc.ErrorInfo",
  │     "domain": "googleapis.com",
  │     "metadata": {
  │       "consumer": "projects/myproject-XXXX",
  │       "service": "secretmanager.googleapis.com"
  │     },
  │     "reason": "CONSUMER_INVALID"
  │   }
  │ ]
  │
  │   with google_secret_manager_secret.sqlppass,
  │   on secrets.tf line 68, in resource "google_secret_manager_secret" "sqlppass":
  │   68: resource "google_secret_manager_secret" "sqlppass" {
  │
  ╵
  ╷
  │ Error: Error creating Secret: googleapi: Error 403: Permission denied on resource project myproject-XXXX.
  │ Details:
  │ [
  │   {
  │     "@type": "type.googleapis.com/google.rpc.Help",
  │     "links": [
  │       {
  │         "description": "Google developer console API key",
  │         "url": "https://console.developers.google.com/project/myproject-XXXX/apiui/credential"
  │       }
  │     ]
  │   },
  │   {
  │     "@type": "type.googleapis.com/google.rpc.ErrorInfo",
  │     "domain": "googleapis.com",
  │     "metadata": {
  │       "consumer": "projects/myproject-XXXX",
  │       "service": "secretmanager.googleapis.com"
  │     },
  │     "reason": "CONSUMER_INVALID"
  │   }
  │ ]
  │
  │   with google_secret_manager_secret.cookie_key,
  │   on secrets.tf line 94, in resource "google_secret_manager_secret" "cookie_key":
  │   94: resource "google_secret_manager_secret" "cookie_key" {
  │
  ╵
  ╷
  │ Error: Unable to verify whether custom project role projects/myproject-XXXX/roles/custom.forwardingRulesSa already exists and must be undeleted: Error when reading or editing Custom Project Role "projects/myproject-XXXX/roles/custom.forwardingRulesSa": googleapi: Error 403: You don't have permission to get the role at projects/myproject-XXXX/roles/custom.forwardingRulesSa., forbidden
  │
  │   with google_project_iam_custom_role.forwardingRulesSa,
  │   on serviceaccount.tf line 17, in resource "google_project_iam_custom_role" "forwardingRulesSa":
  │   17: resource "google_project_iam_custom_role" "forwardingRulesSa" {
  │
  ╵
  ╷
  │ Error: Error creating instance: googleapi: Error 412: Constraint constraints/compute.vmExternalIpAccess violated for project 0123456789. Add instance projects/myproject-XXXX/zones/us-central1-b/instances/bastion-001 to the constraint to use external IP with it., conditionNotMet
  │
  │   with module.bastion_instance.google_compute_instance_from_template.compute_instance[0],
  │   on .terraform/modules/bastion_instance/modules/compute_instance/main.tf line 41, in resource "google_compute_instance_from_template" "compute_instance":
  │   41: resource "google_compute_instance_from_template" "compute_instance" {
  │
  ```
  If this is the case, just wait 30 seconds and relaunch the apply. It should go right after.
  Note: Probably adding some sleep we can solve this problem. Dependency didn't di the trick.