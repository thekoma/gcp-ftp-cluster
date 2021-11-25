output instructions {
  value = "Admin interface: http://${local.haftprecord}/web/admin/login\nAdmin User: ${var.ftp_webadmin_user}\nAdmin Password: ${var.ftp_webadmin_password}\nFTP Single: ftp://${local.ftprecord}\nFTP HA: ftp://${local.haftprecord}\nFTP User: ${var.ftp_demo_user}\nFTP Password: ${var.ftp_demo_password}\nEverything is also accessible via SFTP"
}