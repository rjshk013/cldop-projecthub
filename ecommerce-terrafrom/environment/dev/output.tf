# ########## VPC INFORMATION#############
# output "vpc_info" {
#   description = "VPC information summary"
#   value = {
#     id         = module.vpc.vpc_id
#     cidr       = module.vpc.vpc_cidr_block
#     name       = local.vpc_name
#     region     = var.region
#     azs        = var.availability_zones
#   }
# }

# output "subnet_info" {
#   description = "Subnet information summary"
#   value = {
#     private_subnet_ids   = module.vpc.private_subnets
#     public_subnet_ids    = module.vpc.public_subnets
#     private_subnet_cidrs = module.vpc.private_subnets_cidr_blocks
#     public_subnet_cidrs  = module.vpc.public_subnets_cidr_blocks
#   }
# }

# # # ✅ BASIC NAT GATEWAY OUTPUTS
# # output "nat_gateway_ids" {
# #   description = "List of IDs of the NAT Gateways"
# #   value       = module.vpc.natgw_ids
# # }

# # output "nat_public_ips" {
# #   description = "List of public Elastic IPs used by NAT Gateways"
# #   value       = module.vpc.nat_public_ips
# # }

# # ✅ DETAILED NAT GATEWAY INFORMATION
# output "nat_gateway_info" {
#   description = "Detailed NAT Gateway information"
#   value = {
#     nat_gateway_ids     = module.vpc.natgw_ids
#     elastic_ips         = module.vpc.nat_public_ips
#     count               = length(module.vpc.natgw_ids)
#     availability_zones  = var.availability_zones
#     single_nat_gateway  = var.environment != "prod"
#     environment         = var.environment
#   }
# }

# # Internet Gateway
# output "internet_gateway_id" {
#   description = "The ID of the Internet Gateway"
#   value       = module.vpc.igw_id
# }

# # Route Tables
# output "private_route_table_ids" {
#   description = "List of IDs of the private route tables"
#   value       = module.vpc.private_route_table_ids
# }

# output "public_route_table_ids" {
#   description = "List of IDs of the public route tables"
#   value       = module.vpc.public_route_table_ids
# }


output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    # Environment Information
    environment     = var.environment
    project_name    = var.project_name
    region          = var.aws_region
    
    # VPC Information
    vpc = {
      id   = module.vpc.vpc_id
      cidr = module.vpc.vpc_cidr_block
    }
    
    # Subnet Information
    subnets = {
      private = {
        ids   = module.vpc.private_subnets
        cidrs = module.vpc.private_subnets_cidr_blocks
        count = length(module.vpc.private_subnets)
      }
      public = {
        ids   = module.vpc.public_subnets
        cidrs = module.vpc.public_subnets_cidr_blocks
        count = length(module.vpc.public_subnets)
      }
    }
    
    # NAT Gateway Information
    nat_gateways = {
      ids           = module.vpc.natgw_ids
      elastic_ips   = module.vpc.nat_public_ips
      count         = length(module.vpc.natgw_ids)
      configuration = var.environment == "prod" ? "multi-az" : "single"
    }
    
    # Network Gateways
    gateways = {
      internet_gateway = module.vpc.igw_id
      nat_gateways     = module.vpc.natgw_ids
    }
  }
}

output "security_group_info" {
  description = "Security group information"
  value = {
    # VPN Server Security Group
    vpn_server_sg_id = module.vpn_server_sg.security_group_id
    vpn_server_sg_arn = module.vpn_server_sg.security_group_arn
    vpn_server_sg_name = module.vpn_server_sg.security_group_name
    
    # Private Resources Security Group
    private_resources_sg_id = module.private_resources_sg.security_group_id
    private_resources_sg_arn = module.private_resources_sg.security_group_arn
    private_resources_sg_name = module.private_resources_sg.security_group_name
  }
}

output "vpn_server_info" {
  description = "VPN server information with security group details"
  value = {
    # Instance Information
    public_ip    = module.vpn_server.public_ip
    private_ip   = module.vpn_server.private_ip
    instance_id  = module.vpn_server.id
    
    # Access Information
    #admin_url    = "https://${module.vpn_server.public_ip}"
    ssh_command  = "ssh -p ${var.ssh_port} -i your-key.pem ec2-user@${module.vpn_server.public_ip}"
    
    # Security Group Information
    security_group_id   = module.vpn_server_sg.security_group_id
    security_group_name = module.vpn_server_sg.security_group_name
    
    # Network Configuration
    ssh_port = var.ssh_port
    vpn_port = var.vpn_port
    admin_allowed_ips = var.admin_allowed_ips
    vpn_client_cidr = var.vpn_client_cidr
  }
}

output "private_instance_id" {
  description = "ID of the private EC2 instance"
  value       = module.private_instance.id
}

output "private_instance_private_ip" {
  description = "Private IP address of the private instance"
  value       = module.private_instance.private_ip
}

output "private_instance_sg_id" {
  description = "Security group ID for private instance"
  value       = module.vpn_server_sg.security_group_id
}

output "ninzstore_zone_name_servers" {
  description = "Route53 NS records for ninz.store"
  value       = module.ninzstore_zone.route53_zone_name_servers["ninz.store"]
}
output "ninzstore_zone_id" {
  description = "Hosted Zone ID for ninz.store"
  value       = module.ninzstore_zone.route53_zone_zone_id["ninz.store"]
}