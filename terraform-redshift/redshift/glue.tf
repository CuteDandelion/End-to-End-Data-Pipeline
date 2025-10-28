resource "aws_glue_catalog_database" "example" {
  name = var.glue_database_name
}

resource "aws_iam_role" "glue_service_role" {
  name = var.glue_service_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "secrets_full_access" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy" "glue_service_policy" {
  role   = aws_iam_role.glue_service_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "glue:GetDatabase",
        "glue:GetTables",
        "glue:CreateDatabase",
        "glue:CreateTable",
        "glue:DeleteTable",
        "glue:GetTable",
        "glue:GetTableVersion",
        "glue:GetTableVersions",
        "glue:UpdateTable",
        "glue:CreatePartition",
        "glue:BatchCreatePartition",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchGetPartition",
        "glue:UpdatePartition",
        "glue:DeletePartition",
        "glue:BatchDeletePartition"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3_bucket_name}",
        "arn:aws:s3:::${var.s3_bucket_name}/*",
        "arn:aws:glue:${var.aws_region}:${var.account_id}:catalog",
        "arn:aws:glue:${var.aws_region}:${var.account_id}:database/${var.glue_database_name}",
        "arn:aws:glue:${var.aws_region}:${var.account_id}:table/${var.glue_database_name}/*"
        ]

    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "glue_logs_policy" {
  role   = aws_iam_role.glue_service_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws-glue/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "glue_create_linked_secret_policy" {
  role   = aws_iam_role.glue_service_role.name
  policy = <<EOF
{
  
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "glue_vpc_policy" {
  role   = aws_iam_role.glue_service_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:AttachNetworkInterface",
        "ec2:DetachNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "glue_secrets_policy" {
  role   = aws_iam_role.glue_service_role.name
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:*"
    }
  ]
}
EOF
}

resource "aws_glue_crawler" "example" {
  database_name = aws_glue_catalog_database.example.name
  name          = var.glue_crawler_name
  role          = aws_iam_role.glue_service_role.arn

  s3_target {
    path = "s3://${var.s3_bucket_name}/raw-data/streaming_raw"
    exclusions = ["scripts/*", "lambda2/*"]
  }

  s3_target {
    path = "s3://${var.s3_bucket_name}/processed-data/streaming_anomalies"
    exclusions = ["scripts/*", "lambda2/*"]
  }
}


variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "glue_crawler_name" {
  description = "The name of the Glue Crawler"
  type        = string
  default     = "demo-glue-crawler"
}

variable "glue_service_role_name" {
  description = "The name of the IAM role for the Glue service"
  type        = string
  default     = "demo-glue-role"
}

variable "glue_database_name" {
  description = "The name of the Glue database"
  type        = string
  default     = "demo-glue-db"
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}
