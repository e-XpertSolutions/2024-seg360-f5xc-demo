terraform {
  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = "0.11.37"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "volterra" {
  api_p12_file = var.api_cert
  url          = var.api_url
}

# Configure the AWS Provider
provider "aws" {
  region     = "eu-central-1"
  access_key = var.aws_ecs_access_key
  secret_key = var.aws_ecs_secret_key
}
