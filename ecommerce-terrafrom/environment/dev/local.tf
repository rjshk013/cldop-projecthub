
locals {
  #azs = slice(data.aws_availability_zones.available.names, 0, 3)
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    # Service     = var.service_name
    ManagedBy   = "terraform"
    Region      = var.aws_region
  }
}