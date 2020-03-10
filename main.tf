# Due to issues with this module, aws_infra needs to be deployed first.
# To achieve this, comment the below code, apply, uncomment and do it again.
#
module "tfe-cluster" {
  source                  = "hashicorp/terraform-enterprise/aws"
  version                 = "0.1.2"
  vpc_id                  = "${aws_vpc.demo-tfe.id}"
  domain                  = "${var.domain}"
  license_file            = "${var.license_file}"
  allow_list              = "${var.allow_list}"
  hostname                = "${var.hostname}"
  prefix                  = "${var.prefix}"
  
  postgresql_user         = "${module.external.database_username}"
  postgresql_password     = "${module.external.database_password}"
  postgresql_address      = "${module.external.database_endpoint}"
  postgresql_database     = "${module.external.database_name}"
  postgresql_extra_params = "sslmode=disable"

  s3_bucket               = "${module.external.s3_bucket}"
  s3_region               = "${var.region}"

  aws_access_key_id       = "${module.external.iam_access_key}"
  aws_secret_access_key   = "${module.external.iam_secret_key}"
}
output "tfe-beta" {
  value = {
    application_endpoint         = "${module.tfe-cluster.application_endpoint}"
    application_health_check     = "${module.tfe-cluster.application_health_check}"
    iam_role                     = "${module.tfe-cluster.iam_role}"
    install_id                   = "${module.tfe-cluster.install_id}"
    installer_dashboard_password = "${module.tfe-cluster.installer_dashboard_password}"
    installer_dashboard_url      = "${module.tfe-cluster.installer_dashboard_url}"
    primary_public_ip            = "${module.tfe-cluster.primary_public_ip}"
    ssh_private_key              = "${module.tfe-cluster.ssh_private_key}"
  }
}

