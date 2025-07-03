

//Specifying provider/terraform version
terraform {
  required_version = ">= 1.0.0" // Specify the minimum Terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" // Use the pessimistic constraint operator to allow patches
    }
  }
}


//provider "AWS"
provider "aws" {
  region = "us-east-1"
  #shared_credentials_file = "/home/rajeshk/.aws/credentails"
  profile = "default"
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Organization = "cldop"
    }
  }
}

//Using s3 bucket as remote state management
//terraform init

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "auction-tfstate-remote"
    key            = "state.tfstate"
    region         = "us-east-1"
    # dynamodb_table = "demo-table"
    use_lockfile = true
  }
}