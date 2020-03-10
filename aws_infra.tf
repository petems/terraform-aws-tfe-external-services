provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "demo-tfe" {
  cidr_block           = "${var.vpc_cidr_block}"
  enable_dns_hostnames = true

  tags = {
    Name           = "${var.owner}-TFE-VPC"
    owner          = "${var.owner}"
    created-by     = "${var.owner}"
    sleep-at-night = "${var.sleep-at-night}"
    TTL            = "${var.TTL}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "demo-tfe-pub" {
  count                   = "${length(var.cidr_blocks_pub)}"
  vpc_id                  = "${aws_vpc.demo-tfe.id}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${var.cidr_blocks_pub[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name           = "${var.owner}-pub${count.index}"
    owner          = "${var.owner}"
    created-by     = "${var.owner}"
    sleep-at-night = "${var.sleep-at-night}"
    TTL            = "${var.TTL}"
  }
}

resource "aws_subnet" "demo-tfe-priv" {
  count                   = "${length(var.cidr_blocks_priv)}"
  vpc_id                  = "${aws_vpc.demo-tfe.id}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${var.cidr_blocks_priv[count.index]}"
  map_public_ip_on_launch = false

  tags = {
    Name           = "${var.owner}-priv${count.index}"
    owner          = "${var.owner}"
    created-by     = "${var.owner}"
    sleep-at-night = "${var.sleep-at-night}"
    TTL            = "${var.TTL}"
  }
}

resource "aws_internet_gateway" "demo-tfe" {
  vpc_id = "${aws_vpc.demo-tfe.id}"

  tags = {
    Name           = "${var.owner}-TFE-VPC"
    owner          = "${var.owner}"
    created-by     = "${var.owner}"
    sleep-at-night = "${var.sleep-at-night}"
    TTL            = "${var.TTL}"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.demo-tfe.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.demo-tfe.id}"
}

data "aws_route53_zone" "selected" {
  name = "${var.domain}."
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"

  tags = {
    Name           = "${var.owner}-tfe"
    owner          = "${var.owner}"
    created-by     = "${var.owner}"
    sleep-at-night = "${var.sleep-at-night}"
    TTL            = "${var.TTL}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation_record" {
  name            = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type            = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id         = "${data.aws_route53_zone.selected.zone_id}"
  records         = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl             = "60"
  allow_overwrite = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = "${aws_acm_certificate.cert.arn}"

  validation_record_fqdns = [
    "${aws_route53_record.validation_record.fqdn}",
  ]
}

# External servise infra - DB and S3 storage
module "external" {
  source  = "./modules/external-services"
  version = "0.1.0"

  vpc_id     = "${aws_vpc.demo-tfe.id}"
  install_id = "${module.tfe-cluster.install_id}"
}

data "aws_iam_policy_document" "setup-bucket" {
  statement {
    resources = [
      "arn:aws:s3:::${var.setup_bucket}",
      "arn:aws:s3:::${var.setup_bucket}/*",
    ]

    actions = [
      "s3:*",
    ]
  }
}

resource "aws_iam_role_policy" "setup-bucket" {
  role   = "${module.tfe-cluster.iam_role}"
  name   = "${var.setup_bucket}-${module.tfe-cluster.install_id}"
  policy = "${data.aws_iam_policy_document.setup-bucket.json}"
}

# Outputs
# -----------------------------------------------------------------------------
output "tfe-infra-details" {
  value = {
    postgresql_user     = "${module.external.database_username}"
    postgresql_password = "${module.external.database_password}"
    postgresql_address  = "${module.external.database_endpoint}"
    postgresql_database = "${module.external.database_name}"
  }
}
