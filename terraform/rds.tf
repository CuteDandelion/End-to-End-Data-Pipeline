resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.project_name}-rds-subnets"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-rds-subnets"
  }
}

resource "aws_security_group" "rds_db_sg" {
  name   = "rds-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description      = "Allow DB access from EKS nodes"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  vpc_security_group_ids = [aws_security_group.rds_db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
}
