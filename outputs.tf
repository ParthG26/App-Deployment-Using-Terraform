output "vpc_created" {
  description = "VPC has been created"
  value       = "VPC ID: ${aws_vpc.main.id}"
}

output "frontend_instance_id" {
  description = "Frontend EC2 Instance ID"
  value       = "Frontend Instance ID: ${aws_instance.Frontend.id}"
}

output "backend_instance_id" {
  description = "Backend EC2 Instance ID"
  value       = "Backend Instance ID: ${aws_instance.Backend.id}"
}

output "rds_instance_id" {
  description = "RDS Instance ID"
  value       = "RDS Instance ID: ${aws_db_instance.DB.id}"
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = [
    aws_subnet.subnets["Public1"].id,
    aws_subnet.subnets["Public2"].id
  ]
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = [
    aws_subnet.subnets["Private1"].id,
    aws_subnet.subnets["Private2"].id
  ]
}

output "frontend_public_ip" {
  description = "Public IP of the Frontend EC2 Instance"
  value       = aws_instance.Frontend.public_ip
}
