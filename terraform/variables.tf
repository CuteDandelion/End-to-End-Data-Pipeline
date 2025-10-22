variable "region" {
  default = "us-east-1"
}

variable "eks_cluster_name" {
  default = "demo-eks-cluster"
}

variable "project_name" {
  default = "data-pipeline"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "db_username" {
  default = "dandy"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
