variable "project"           {}
variable "environment"       {}
variable "vpc_id"            {}
variable "db_subnet_ids"     { type = list(string) }
variable "app_sg_id"         {}
variable "instance_class"    {}
variable "engine"            {}
variable "engine_version"    {}
variable "db_name"           {}
variable "username"          { sensitive = true }
variable "password"          { sensitive = true }
variable "allocated_storage" { type = number }

locals {
  prefix = "${var.project}-${var.environment}"
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${local.prefix}-db-sg"
  description = "Allow DB traffic from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.prefix}-db-sg" }
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${local.prefix}-db-subnet-group" }
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier              = "${local.prefix}-rds"
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  multi_az                = true
  publicly_accessible     = false
  deletion_protection     = true
  backup_retention_period = 7
  skip_final_snapshot     = false
  final_snapshot_identifier = "${local.prefix}-rds-final-snapshot"
  tags = { Name = "${local.prefix}-rds" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "db_endpoint" { value = aws_db_instance.this.endpoint }
