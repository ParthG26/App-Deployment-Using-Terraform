resource "tls_private_key" "pri_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ChatApp_key" {
  key_name   = "ChatApp-key"
  public_key = tls_private_key.pri_key.public_key_openssh
}
resource "aws_instance" "Backend" {
  ami                    = "ami-0e35ddab05955cf57"
  key_name               = aws_key_pair.ChatApp_key.key_name
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = [var.private_sg_id]
  tags = {
    Name = "Backend"
  }
}
resource "null_resource" "backend" {
  depends_on = [aws_instance.Backend,aws_instance.Frontend]
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
      "sudo apt install -y software-properties-common",
      "sudo add-apt-repository ppa:deadsnakes/ppa -y",
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
      "grep -qxF 'DB_HOST=${var.db_host}' /.env || echo 'DB_HOST=${var.db_host}' | sudo tee -a /.env",
      "echo 'Writing to host started' || true",
      "grep -qxF 'DB_PORT=3306' /.env || echo 'DB_PORT=3306' | sudo tee -a /.env"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chown -R ubuntu:ubuntu /chat_app",
      "cd /chat_app",
      "python3.8 -m venv venv",
      "bash -c 'source venv/bin/activate && pip install -r /chat_app/requirements.txt && pip install gunicorn mysqlclient python-dotenv'",
    ]
  }
  provisioner "remote-exec"{
    inline=[
      "cd /chat_app/fundoo",
      "grep -qxF 'from dotenv import load_dotenv' /.env || sed -i '/import os/a from dotenv import load_dotenv\\nload_dotenv(\"/.env\")' fundoo/settings.py",
      "mysql -h ${var.db_host} -u ${var.db_user} -p${var.db_password} -e 'CREATE DATABASE IF NOT EXISTS ${var.db_name};'",
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
resource "aws_instance" "Frontend" {
  ami                         = "ami-0e35ddab05955cf57"
  key_name                    = aws_key_pair.ChatApp_key.key_name
  subnet_id                   = var.public_subnets[0]
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [var.public_sg_id]
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
      "chmod 400 /home/ubuntu/ChatApp_key.pem",
      "sudo apt update",
      "sudo apt install nginx -y",
      "echo 'server { listen 80; server_name _; location / { proxy_pass http://${aws_instance.Backend.private_ip}:8000; } }' | sudo tee /etc/nginx/sites-available/chatapp",
      "sudo ln -s /etc/nginx/sites-available/chatapp /etc/nginx/sites-enabled/",
      "sudo unlink /etc/nginx/sites-enabled/default || true",
      "sudo systemctl restart nginx"
    ]
  }
}
