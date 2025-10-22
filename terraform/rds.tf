resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.project_name}-rds-subnets"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-rds-subnets"
  }
}

resource "aws_db_instance" "rds" {
  identifier        = "${var.project_name}-rds"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = var.db_username
  password          = var.db_password
  skip_final_snapshot = true
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.eks_cluster_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
}
