variable "tenant_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Deploy a NAT Gateway for internet egress. Set to false for fully private environments."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
