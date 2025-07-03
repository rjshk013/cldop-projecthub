
locals {
  #azs = slice(data.aws_availability_zones.available.names, 0, 3)
  name_prefix = "${var.project_name}-${var.environment}"
  # Create a meaningful name using your variables
  #vpc_name = "${var.project_name}-${var.environment}-${var.service_name}"
  # domain_name = var.domain_name
  # current_ip = "${chomp(data.http.current_ip.response_body)}/32"
  
  # Combine with any static IPs you want to keep
  # admin_allowed_ips = [
  #   local.current_ip,
  #   # Add any static IPs here if needed
  #   # "203.0.113.100/32",  # Office IP
  #   # "198.51.100.50/32",  # Backup location
  # ]
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    # Service     = var.service_name
    ManagedBy   = "terraform"
    Region      = var.region
  }
}