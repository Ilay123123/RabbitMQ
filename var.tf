# variables_first_try.tf
variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0e2c8caa4b6378d8c"
  # Use Ubuntu 20.04 LTS AMI ID for your region
}

variable "cluster_size" {
  description = "Number of nodes in the RabbitMQ cluster"
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Number of nodes in the RabbitMQ cluster"
  type        = number
  default     = 5
}

variable "min_size" {
  description = "Number of nodes in the RabbitMQ cluster"
  type        = number
  default     = 1
}
