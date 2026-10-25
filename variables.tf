variable "aws_region" {
  description = "The AWS region to deploy the resources in"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ubuntu-nginx-login-server"
}

variable "key_name" {
  description = "Optional EC2 Key Pair name for SSH access (must exist in AWS region)"
  type        = string
  default     = null
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access (port 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
