variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile"
  type        = string
  default     = "eks-lab"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "aws-kubernetes-lab"
}
