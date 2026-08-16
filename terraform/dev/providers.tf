provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-kubernetes-lab"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
