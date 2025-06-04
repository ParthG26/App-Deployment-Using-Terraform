variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnets" {
  default = {
    Public1  = { cidr = "10.0.1.0/24", az = "ap-south-1a" }
    Public2  = { cidr = "10.0.2.0/24", az = "ap-south-1b" }
    Private1 = { cidr = "10.0.3.0/24", az = "ap-south-1a" }
    Private2 = { cidr = "10.0.4.0/24", az = "ap-south-1b" }
  }
}
variable "db_name" {
  description = "The name for the RDS Instance"
  type        = string
  default     = "ChatApp"
}
variable "db_user" {
  description = "The Username for the RDS Instance"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "The Password for the RDS Instance"
  type        = string
  default     = "chatapp_admin"
}