resource "aws_s3_bucket" "tfe_objects" {
  bucket = "${var.install_id}"
}
