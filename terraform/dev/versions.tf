terraform {
  required_version = ">= 1.15.0"

  backend "s3" {
    bucket       = "aws-kubernetes-lab-tfstate-naki0227-20260816"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
