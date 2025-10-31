#############################
## Redshift Cluster - Main ##
#############################

# Create the Redshift Cluster
resource "aws_redshift_cluster" "redshift-cluster" {
  depends_on = [
    aws_vpc.redshift-vpc,
    aws_redshift_subnet_group.redshift-subnet-group,
    aws_iam_role.redshift-role
  ]

  cluster_identifier = var.redshift_cluster_identifier
  database_name      = var.redshift_database_name
  master_username    = var.redshift_admin_username
  master_password    = var.redshift_admin_password
  node_type          = var.redshift_node_type
  cluster_type       = var.redshift_cluster_type
  number_of_nodes    = var.redshift_number_of_nodes

  iam_roles = [aws_iam_role.redshift-role.arn]

  cluster_subnet_group_name = aws_redshift_subnet_group.redshift-subnet-group.id
  
  skip_final_snapshot = true

  tags = {
    Name        = "${var.app_name}-${var.app_environment}-redshift-cluster"
    Environment = var.app_environment
  }
}

# --- STS Endpoint ---
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.redshift-vpc.id
  service_name        = "com.amazonaws.us-east-2.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_redshift_subnet_group.redshift-subnet-group.subnet_ids
  security_group_ids  = [aws_default_security_group.redshift_security_group.id]
  private_dns_enabled = true
}

# --- Glue Endpoint ---
resource "aws_vpc_endpoint" "glue" {
  vpc_id              = aws_vpc.redshift-vpc.id
  service_name        = "com.amazonaws.us-east-2.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_redshift_subnet_group.redshift-subnet-group.subnet_ids
  security_group_ids  = [aws_default_security_group.redshift_security_group.id]
  private_dns_enabled = true
}

# --- Secrets Manager Endpoint ---
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.redshift-vpc.id
  service_name        = "com.amazonaws.us-east-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_redshift_subnet_group.redshift-subnet-group.subnet_ids
  security_group_ids  = [aws_default_security_group.redshift_security_group.id]
  private_dns_enabled = true
}
