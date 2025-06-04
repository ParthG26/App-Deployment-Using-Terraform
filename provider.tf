terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
  backend "s3" {
    bucket = "my-test-balti-69"
    key    = "Test-StateFiles/Terraform.tfstate"
    region = "ap-south-1"
  }

  required_version = ">=1.2.0"
}

provider "aws" {
  region = var.region
}
