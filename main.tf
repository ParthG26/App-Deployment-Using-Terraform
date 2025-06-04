
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "Terraform-VPC"
  }
}

resource "aws_subnet" "subnets" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = {
    Name = each.key
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "ChatApp-IGW"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnets["Public1"].id
  tags = {
    Name = "ChatApp-NATGW"
  }
}

resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public-RT"
  }
}

resource "aws_route_table" "privatert" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "Private-RT"
  }
}

resource "aws_route_table_association" "public_assoc" {
  route_table_id = aws_route_table.publicrt.id
  for_each = {
    public-1a = aws_subnet.subnets["Public1"].id
    public-1b = aws_subnet.subnets["Public2"].id
  }
  subnet_id = each.value
}

resource "aws_route_table_association" "private_assoc" {
  route_table_id = aws_route_table.privatert.id
  for_each = {
    private-1a = aws_subnet.subnets["Private1"].id
    private-1b = aws_subnet.subnets["Private2"].id
  }
  subnet_id = each.value
}

resource "aws_security_group" "public_sg" {
  name        = "PublicSG"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  name        = "Private_SG"
  description = "Allow Backend Access"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "RDS-SG"
  description = "Allow MYSQL Access from backend"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.private_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_db_subnet_group" "db_subnet_group" {
  name = "chat-db-subnet"
  subnet_ids = [
    aws_subnet.subnets["Private1"].id,
    aws_subnet.subnets["Private2"].id
  ]
  tags = {
    Name = "ChatApp-DB-Subnet"
  }
}
resource "tls_private_key" "pri_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ChatApp_key" {
  key_name   = "ChatApp-key"
  public_key = tls_private_key.pri_key.public_key_openssh
}
resource "aws_db_instance" "DB" {
  identifier             = "chatapp"
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.db_user
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible    = false
  skip_final_snapshot    = true
  tags = {
    Name = "ChatApp"
  }
}
resource "aws_instance" "Backend" {
  ami                    = "ami-0e35ddab05955cf57"
  key_name               = aws_key_pair.ChatApp_key.key_name
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnets["Private1"].id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  tags = {
    Name = "Backend"
  }
}

resource "aws_instance" "Frontend" {
  ami                         = "ami-0e35ddab05955cf57"
  key_name                    = aws_key_pair.ChatApp_key.key_name
  subnet_id                   = aws_subnet.subnets["Public1"].id
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "Frontend"
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.pri_key.private_key_pem
    host        = self.public_ip
  }
  provisioner "file" {
    content     = tls_private_key.pri_key.private_key_pem
    destination = "/home/ubuntu/ChatApp-key.pem"
  }
}
resource "null_resource" "backend" {
  depends_on = [aws_instance.Backend]
  triggers = {
    always_run = "${timestamp()}"
  }
  connection {
    type                = "ssh"
    user                = "ubuntu"
    private_key         = tls_private_key.pri_key.private_key_pem
    host                = aws_instance.Backend.private_ip
    bastion_host        = aws_instance.Frontend.public_ip
    bastion_private_key = tls_private_key.pri_key.private_key_pem
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y git pkg-config python3.8 python3.8-venv python3.8-dev python3-pip build-essential default-libmysqlclient-dev software-properties-common mysql-client",
      "cd / || echo 'Missing repo directory'",
      "sudo test -d /chat_app || sudo git clone https://github.com/ARPIT226/chat_app.git"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Writing to .env started' || true",
      "grep -qxF 'DB_NAME=${var.db_name}' /.env || echo 'DB_NAME=${var.db_name}' | sudo tee -a /.env",
      "echo 'Writing to name started' || true",
      "grep -qxF 'DB_USER=${var.db_user}' /.env || echo 'DB_USER=${var.db_user}' | sudo tee -a /.env",
      "echo 'Writing to user started' || true",
      "grep -qxF 'DB_PASSWORD=${var.db_password}' /.env || echo 'DB_PASSWORD=${var.db_password}' | sudo tee -a /.env",
      "echo 'Writing to password started' || true",
      "grep -qxF 'DB_HOST=${aws_db_instance.DB.address}' /.env || echo 'DB_HOST=${aws_db_instance.DB.address}' | sudo tee -a /.env",
      "echo 'Writing to host started' || true",
      "grep -qxF 'DB_PORT=3306' /.env || echo 'DB_PORT=3306' | sudo tee -a /.env"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ubuntu:ubuntu /chat_app",
      "cd /chat_app",
      "python3.8 -m venv venv",
      "bash -c 'source venv/bin/activate && pip install -r /chat_app/requirements.txt && pip install gunicorn mysqlclient'",
    ]
  }
  provisioner "remote-exec"{
    inline=[
      "cd /chat_app/fundoo",
      "grep -qxF 'from dotenv import load_dotenv' /.env || sed -i '/import os/a from dotenv import load_dotenv\\nload_dotenv(\"/.env\")' fundoo/settings.py",
      "bash -c 'source /chat_app/venv/bin/activate && python3 manage.py makemigrations && python3 manage.py migrate'"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "echo '[Unit]' | sudo tee /etc/systemd/system/gunicorn.service",
      "echo 'Description=gunicorn daemon for Django app' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'After=network.target' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo '[Service]' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'User=ubuntu' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'Group=www-data' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'WorkingDirectory=/chat_app/fundoo' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'Environment=\"PATH=/chat_app/venv/bin\"' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'ExecStart=/chat_app/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8000 fundoo.wsgi:application' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo '[Install]' | sudo tee -a /etc/systemd/system/gunicorn.service",
      "echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/gunicorn.service"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl enable gunicorn",
      "sudo systemctl start gunicorn"
    ]
  }
}
resource "null_resource" "frontend" {
  depends_on = [aws_instance.Frontend]
  triggers = {
    always_run = "${timestamp()}"
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.pri_key.private_key_pem
    host        = aws_instance.Frontend.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y",
      "echo 'server { listen 80; server_name _; location / { proxy_pass http://${aws_instance.Backend.private_ip}:8000; } }' | sudo tee /etc/nginx/sites-available/chatapp",
      "sudo ln -s /etc/nginx/sites-available/chatapp /etc/nginx/sites-enabled/",
      "sudo unlink /etc/nginx/sites-enabled/default || true",
      "sudo systemctl restart nginx"
    ]
  }
}