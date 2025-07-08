variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"  # ✅ This prevents prompting
}

variable "aws_profile" {
  description = "The AWS CLI profile to use"
  type        = string
  default     = "default"
}
variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
  
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 6
    error_message = "AZ count must be between 1 and 6."
  }
}
#####naming convention##################
variable "project_name" {
  description = "project name."
  type        = string
  default     = "finops"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "stage" {
  description = "Stage of the deployment."
  type        = string
  default     = "dev"
}


##network ######
variable "vpc_cidr" {
  description = "(Optional) The IPv4 CIDR block for the VPC. CIDR can be explicitly set or it can be derived from IPAM using `ipv4_netmask_length` & `ipv4_ipam_pool_id`"
  type        = string
  default     = "10.0.0.0/16"
}
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cost optimization)"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}


# variables.tf - Add VPN specific variables
variable "vpn_instance_type" {
  description = "Instance type for VPN server"
  type        = string
  default     = "t3.small"
  
  validation {
    condition = contains(["t3.micro", "t3.small", "t3.medium"], var.vpn_instance_type)
    error_message = "VPN instance type must be t3.micro, t3.small, or t3.medium."
  }
}

variable "vpn_port" {
  description = "Port for VPN connections"
  type        = number
  default     = 1194
}

variable "ssh_port" {
  description = "Custom SSH port for security"
  type        = number
  default     = 22022
}

variable "admin_allowed_ips" {
  description = "List of IP addresses allowed admin access"
  type        = list(string)
  default     = [
    "0.0.0.0/0",  # Replace with your office IP
    "103.175.88.75/32"   # Replace with your home IP
  ]
  
  validation {
    condition = length(var.admin_allowed_ips) > 0
    error_message = "At least one admin IP must be specified for security."
  }
}

variable "vpn_client_cidr" {
  description = "CIDR block for VPN clients (configure this in Pritunl)"
  type        = string
  default     = "10.0.4.0/24"
}

variable "public_key_path" {
  description = "Path to your local public key file"
  type        = string
  default     = "~/.ssh/devserver_key.pub"
}
variable "private_key_path" {
  description = "Path to your local public key file"
  type        = string
  default     = "~/.ssh/devserver_key"
}
####R53  ##############

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = "ninz.store"
}
