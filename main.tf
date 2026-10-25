terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Look up the latest official Ubuntu 22.04 LTS (Jammy) AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Security group opening SSH (22), HTTP (80), and HTTPS (443)
resource "aws_security_group" "web_sg" {
  name_prefix = "nginx-login-sg-"
  description = "Allow inbound SSH, HTTP, and HTTPS traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Ubuntu EC2 instance
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail

              # Update system packages and install Nginx & OpenSSL
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y nginx openssl curl

              # Obtain instance public IP for self-signed SSL CN/SAN (IMDSv2 & fallback)
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
              if [ -n "$TOKEN" ]; then
                PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')
              else
                PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')
              fi

              if [ -z "$PUBLIC_IP" ]; then
                PUBLIC_IP="127.0.0.1"
              fi

              # Generate self-signed SSL certificate
              mkdir -p /etc/nginx/ssl
              openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/nginx/ssl/nginx-selfsigned.key \
                -out /etc/nginx/ssl/nginx-selfsigned.crt \
                -subj "/C=US/ST=State/L=City/O=Web/OU=IT/CN=$PUBLIC_IP" \
                -addext "subjectAltName=IP:$PUBLIC_IP,DNS:localhost"

              chmod 600 /etc/nginx/ssl/nginx-selfsigned.key
              chmod 644 /etc/nginx/ssl/nginx-selfsigned.crt

              # Deploy login.html and index.html into /var/www/html
              mkdir -p /var/www/html
              rm -f /var/www/html/index.nginx-debian.html
              echo '${base64encode(file("${path.module}/login.html"))}' | base64 -d > /var/www/html/login.html
              echo '${base64encode(file("${path.module}/index.html"))}' | base64 -d > /var/www/html/index.html
              chown -R www-data:www-data /var/www/html
              chmod 644 /var/www/html/login.html /var/www/html/index.html

              # Configure Nginx for HTTP (port 80) and HTTPS (port 443)
              cat << 'NGINX_CONF' > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  server_name _;

                  root /var/www/html;
                  index login.html index.html;

                  location / {
                      try_files $uri $uri/ =404;
                  }
              }

              server {
                  listen 443 ssl default_server;
                  listen [::]:443 ssl default_server;
                  server_name _;

                  ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
                  ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

                  ssl_protocols TLSv1.2 TLSv1.3;
                  ssl_ciphers HIGH:!aNULL:!MD5;
                  ssl_prefer_server_ciphers on;

                  root /var/www/html;
                  index login.html index.html;

                  location / {
                      try_files $uri $uri/ =404;
                  }
              }
              NGINX_CONF

              # Test configuration and restart Nginx
              nginx -t
              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = var.instance_name
  }
}
