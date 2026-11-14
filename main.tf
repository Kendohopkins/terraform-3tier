terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "web" {
  source = "./modules/web"

  project             = var.project
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  instance_type       = var.web_instance_type
  ami_id              = data.aws_ami.amazon_linux_2023.id
  min_size            = var.web_min_size
  max_size            = var.web_max_size
  desired_capacity    = var.web_desired_capacity
  app_sg_id           = module.app.app_sg_id
}

module "app" {
  source = "./modules/app"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type     = var.app_instance_type
  ami_id            = data.aws_ami.amazon_linux_2023.id
  min_size          = var.app_min_size
  max_size          = var.app_max_size
  desired_capacity  = var.app_desired_capacity
  web_sg_id         = module.web.web_alb_sg_id
}

module "db" {
  source = "./modules/db"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  db_subnet_ids      = module.vpc.db_subnet_ids
  app_sg_id          = module.app.app_sg_id
  instance_class     = var.db_instance_class
  engine             = var.db_engine
  engine_version     = var.db_engine_version
  db_name            = var.db_name
  username           = var.db_username
  password           = var.db_password
  allocated_storage  = var.db_allocated_storage
}
