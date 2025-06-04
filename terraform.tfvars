vpc_cidr = "20.0.0.0/16"

subnets = {
  Public1 = {
    cidr = "20.0.1.0/24"
    az   = "us-east-1a"
  }
  Public2 = {
    cidr = "20.0.2.0/24"
    az   = "us-east-1b"
  }
  Private1 = {
    cidr = "20.0.3.0/24"
    az   = "us-east-1a"
  }
  Private2 = {
    cidr = "20.0.4.0/24"
    az   = "us-east-1b"
  }
}

db_user     = "admin"
db_password = "chatapp_admin"
db_name     = "ChatApp"
