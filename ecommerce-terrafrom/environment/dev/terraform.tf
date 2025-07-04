terraform {
  # Terraform version requirement
  required_version = ">= 1.6.0"

  # Backend configuration for remote state
  backend "s3" {
    encrypt      = true
    bucket       = "finops-remote-tfstate"
    key          = "envs/dev/state.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    

    
  }

  # Required providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AWS Provider configuration
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  
}