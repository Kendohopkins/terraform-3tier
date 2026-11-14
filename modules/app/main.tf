variable "project"            {}
variable "environment"        {}
variable "vpc_id"             {}
variable "private_subnet_ids" { type = list(string) }
variable "instance_type"      {}
variable "ami_id"             {}
variable "min_size"           { type = number }
variable "max_size"           { type = number }
variable "desired_capacity"   { type = number }
variable "web_sg_id"          {}

locals {
  prefix = "${var.project}-${var.environment}"
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${local.prefix}-app-sg"
  description = "Allow traffic from web tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.web_sg_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.prefix}-app-sg" }
}

# ── Internal ALB for App Tier ─────────────────────────────────────────────────
resource "aws_lb" "app" {
  name               = "${local.prefix}-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = var.private_subnet_ids
  tags               = { Name = "${local.prefix}-app-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${local.prefix}-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "${local.prefix}-app-tg" }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── Launch Template + ASG ─────────────────────────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${local.prefix}-app-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    # Install your application runtime here
    echo "App tier ready on $(hostname)"
  EOF
  )

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.prefix}-app-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "${local.prefix}-app"
    propagate_at_launch = true
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "app_sg_id"       { value = aws_security_group.app.id }
output "app_alb_dns"     { value = aws_lb.app.dns_name }
