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
