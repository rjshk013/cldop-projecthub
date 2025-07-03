
module "vpc" {
  source = "/home/user/auction-project/terraform/modules/terraform-aws-vpc"
  
  name = "${local.name_prefix}-vpc" 
  cidr = var.vpc_cidr 
  #azs  = local.azs
  azs  = var.availability_zones
  

  private_subnets = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k + 4)]
  
  # Enable common VPC features
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.environment == "prod" ? false : true
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  
  # Pass your custom tags
  tags = local.common_tags
}

module "vpn_server_sg" {
  source = "/home/user/auction-project/terraform/modules/terraform-aws-security-group"

  name        = "${local.name_prefix}-vpn-server-sg"
  description = "Security group for Pritunl VPN server"
  vpc_id      = module.vpc.vpc_id

  # ✅ ONLY ONE PLACE to define ingress rules
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "Pritunl admin interface from admin IPs only"
    },
    {
      from_port   = 1194
      to_port     = 1194
      protocol    = "udp"
      cidr_blocks = "0.0.0.0/0"
      description = "OpenVPN access from anywhere"
    },
    {
      from_port   = var.ssh_port
      to_port     = var.ssh_port
      protocol    = "tcp"
      cidr_blocks = join(",", var.admin_allowed_ips)
      description = "SSH access from admin IPs only"
    },
        {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks =  "0.0.0.0/0"
      description = "HTTP access from admin IPs only"
    }
  ]
  


  egress_rules = ["all-all"]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpn-server-sg"
    Type = "VPN-Server-Security-Group"
  })
}

# ============================================================================
# 3. PRIVATE RESOURCES SECURITY GROUP
# ============================================================================

module "private_resources_sg" {
  source  = "/home/user/auction-project/terraform/modules/terraform-aws-security-group"
  #version = "5.2.0"

  # ✅ BASIC CONFIGURATION
  name        = "${local.name_prefix}-private-sg"
  description = "Security group for private resources accessible via VPN"
  vpc_id      = module.vpc.vpc_id

  # ✅ ALLOW ACCESS FROM VPN CLIENTS
  ingress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = var.vpn_client_cidr
      description = "Full access from VPN clients"
    },
      {
    rule        = "all-all"
    cidr_blocks = var.vpc_cidr
    description = "Full access from VPC CIDR"
  }
]
  

  # ✅ ALLOW ACCESS FROM VPN SERVER
  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.vpn_server_sg.security_group_id
      description             = "Full access from VPN server"
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  # ✅ EGRESS RULES
  egress_rules = ["all-all"]

  # ✅ TAGS
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-resources-sg"
    Type = "Private-Resources-Security-Group"
  })
}
# ============================================================================
# 6. VPN SERVER EC2 INSTANCE (UPDATED TO USE SECURITY GROUP MODULE)
# ============================================================================

module "vpn_server" {
  source  = "/home/user/auction-project/terraform/modules/terraform-aws-ec2-instance"
  #version = "5.7.0"

  # ✅ BASIC CONFIGURATION
  name = "${local.name_prefix}-vpn-server"
  
  # ✅ INSTANCE CONFIGURATION
  ami                     = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.vpn_instance_type
  key_name               = var.key_pair_name
  monitoring             = true
  enable_volume_tags = false
  
  # ✅ NETWORK CONFIGURATION
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [module.vpn_server_sg.security_group_id]  # ← Using module output
  associate_public_ip_address = true
  source_dest_check          = false

  # ✅ STORAGE CONFIGURATION
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # ✅ USER DATA
  user_data = (templatefile("${path.module}/scripts/full-pritunl.sh", {
    hostname     = "${local.name_prefix}-vpn-server"
    ssh_port     = var.ssh_port
    vpn_port     = var.vpn_port
    admin_ips    = join(" ", var.admin_allowed_ips)
  }))

  # ✅ INSTANCE METADATA SECURITY
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  # ✅ TAGS
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-vpn-server"
    Type        = "VPN-Server"
    Environment = var.environment
  })
}

# ============================================================================
# 7. PRIVATE EC2 INSTANCE
# ============================================================================

module "private_instance" {
  source = "/home/user/auction-project/terraform/modules/terraform-aws-ec2-instance"

  # ✅ BASIC CONFIGURATION
  name = "${local.name_prefix}-app-server"

  # ✅ INSTANCE CONFIGURATION
  ami                = data.aws_ami.ubuntu.id
  instance_type      = var.vpn_instance_type
  key_name          = var.key_pair_name
  monitoring        = true
  enable_volume_tags = false

  # ✅ NETWORK CONFIGURATION - Place in PRIVATE subnet
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [module.private_resources_sg.security_group_id]
  associate_public_ip_address = false  # Private instance - no public IP
  source_dest_check          = true    # Default for private instances

  # ✅ STORAGE CONFIGURATION
  root_block_device = {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # ✅ USER DATA - Basic setup for Amazon Linux 2023
  user_data = (templatefile("${path.module}/scripts/ubuntu_hardening.sh", {
    hostname = "${local.name_prefix}-private-instance"
  }))

  # ✅ INSTANCE METADATA SECURITY
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }

  # ✅ TAGS
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-private-instance"
    Type        = "Private-Instance"
    Environment = var.environment
    Tier        = "Private"
  })
}

###r53##########
module "ninzstore_zone" {
  source = "/home/user/auction-project/terraform/modules/terraform-aws-route53/modules/zones"

  zones = {
    (var.domain_name) = {
      comment = "Public hosted zone for ${var.domain_name}"
      tags = {
        Name = var.domain_name
      }
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}


resource "aws_route53_record" "vpn_server_a_record" {
  zone_id = module.ninzstore_zone.route53_zone_zone_id["ninz.store"]
  name    = "vpn"  # This creates vpn.ninz.store
  type    = "A"
  ttl     = 300
  records = [module.vpn_server.public_ip]
}

# resource "null_resource" "vpn_post_dns_nginx_ssl" {
#   # ✅ Move triggers to the top for better readability
#   triggers = {
#     # Only run when specific things change
#     vpn_server_ip = module.vpn_server.public_ip
#     domain_name   = var.domain_name
#     # Optional: Add Route53 record FQDN as trigger
#     vpn_fqdn     = aws_route53_record.vpn_server_a_record.fqdn
#   }
  
#   # ✅ Keep your existing depends_on
#   depends_on = [aws_route53_record.vpn_server_a_record]
  
#   # ✅ Your existing connection block (perfect as-is)
#   connection {
#     type        = "ssh"
#     user        = "ec2-user"
#     private_key = file(var.private_key_path)  # safer and flexible
#     host        = module.vpn_server.public_ip
#   }
  
#   # ✅ Your existing provisioners (with minor improvements)
#   provisioner "file" {
#     source      = "${path.module}/scripts/nginx-ssl.sh"
#     destination = "/tmp/nginx-ssl.sh"
#   }
  
#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /tmp/nginx-ssl.sh",
#       "bash /tmp/nginx-ssl.sh"  
#     ]
#   }
# }