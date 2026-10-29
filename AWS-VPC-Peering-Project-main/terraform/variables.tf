variable "aws_region" {
  description = "AWS Region where the VPC peering lab resources are deployed."
  type        = string
  default     = "ap-south-1" # Mumbai region
}

variable "key_name" {
  description = "Name of the existing EC2 key pair used for SSH access across all lab instances (e.g., ewb-lab)."
  type        = string
  default     = "ewb-lab"
}

variable "admin_ip" {
  description = "Trusted administrator public IPv4 address in CIDR notation (e.g. 203.0.113.10/32). In production, avoid 0.0.0.0/0 to prevent public SSH exposure."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.admin_ip, 0))
    error_message = "The admin_ip variable must be a valid IPv4 CIDR string, such as '203.0.113.10/32' or '0.0.0.0/0'."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Bastion, App-A, and App-B."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t2.micro", "t2.small"], var.instance_type)
    error_message = "Allowed instance types: t3.micro, t3.small, t2.micro, t2.small."
  }
}
