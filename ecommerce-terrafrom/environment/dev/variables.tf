variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"  # ✅ This prevents prompting
}

variable "logging_level" {
  type        = string
  description = "The logging level of the API. One of - OFF, INFO, ERROR"
  default     = "INFO"

  validation {
    condition     = contains(["OFF", "INFO", "ERROR"], var.logging_level)
    error_message = "Valid values for var: logging_level are (OFF, INFO, ERROR)."
  }
}
variable "enabled" {
  description = "Flag to enable or disable the module."
  type        = bool
  default     = true
}
#####naming convention##################
variable "project_name" {
  description = "Namespace for resource naming."
  type        = string
  default     = "auction"
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

variable "service_name" {
  description = "Name of the service."
  type        = string
  default     = "vpc"
}

##network ######
variable "vpc_cidr" {
  description = "(Optional) The IPv4 CIDR block for the VPC. CIDR can be explicitly set or it can be derived from IPAM using `ipv4_netmask_length` & `ipv4_ipam_pool_id`"
  type        = string
  default     = "10.0.0.0/16"
}
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
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



variable "attributes" {
  description = "Additional attributes for resource naming."
  type        = list(string)
  default     = ["attr1", "attr2"]
}

variable "tags" {
  description = "Standard tags for the resources."
  type        = map(string)
  default     = {
    Owner = "DevOps"
  }
}

variable "additional_tag_map" {
  description = "Additional tags for tagging resources."
  type        = map(string)
  default     = {
    env = "production"
  }
}

variable "regex_replace_chars" {
  description = "Regex pattern to replace characters in labels."
  type        = string
  default     = "/[^\\w]/_"
}

variable "label_order" {
  description = "Order of label parts for constructing names."
  type        = list(string)
  default     = ["namespace", "environment", "stage", "name"]
}

variable "id_length_limit" {
  description = "Maximum length of identifiers."
  type        = number
  default     = 30
}

variable "label_key_case" {
  description = "Case format for label keys."
  type        = string
  default     = "lower"
}

variable "label_value_case" {
  description = "Case format for label values."
  type        = string
  default     = "lower"
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

variable "key_pair_name" {
  description = "EC2 Key Pair name for VPN server"
  type        = string
  default     = "python-test"  # Replace with your actual key pair name
}

variable "vpn_port" {
  description = "Port for VPN connections"
  type        = number
  default     = 1194
}

variable "ssh_port" {
  description = "Custom SSH port for security"
  type        = number
  default     = 22
}

variable "admin_allowed_ips" {
  description = "List of IP addresses allowed admin access"
  type        = list(string)
  default     = [
    "103.175.88.30/32",  # Replace with your office IP
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
####R53  ##############

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = "ninz.store"
}

variable "private_key_path" {
  description = "Path to the SSH private key for connecting to EC2 instances"
  type        = string
  default="/home/user/python-test.pem"
}

variable "run_ssl_setup" {
  description = "Whether to run SSL setup"
  type        = bool
  default     = false  # Set to false to disable
}