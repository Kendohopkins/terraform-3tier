output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS of the Application Load Balancer"
  value       = module.web.alb_dns_name
}

output "db_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.db.db_endpoint
  sensitive   = true
}
