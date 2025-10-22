resource "aws_s3_bucket" "pipeline_data" {
  bucket = "${var.project_name}-data-bucket-${random_id.s3_suffix.hex}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "random_id" "s3_suffix" {
  byte_length = 4
}
