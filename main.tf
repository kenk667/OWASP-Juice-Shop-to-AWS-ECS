#terraform backend set up and provider has AWS creds omitted because this project assumes a terrafrom.tfvars with aws_profile and aws_shared_credentials_file values declard in .tfvars
#aws_region seems to fail if used in .tfvars and is declared in a seperate variab;es.tf file for repeatability and ease

terraform {
  backend "s3" {
    bucket = "wrn-demo"
    key    = "terraform/state"
    region = var.aws_region
  }
}
provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.main.id 
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  
  tags = {
    Name = "subnet2" 
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "main-rt"
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main.id
}

// ... existing code ...

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "juice_shop" {
  name        = "juice-shop-sg"
  description = "Security group for Juice Shop instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "wide open owasp juice shop"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "juice-shop-sg"
  }
}

resource "aws_instance" "juice_shop" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  metadata_options {
    http_tokens = "required"
  }
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.juice_shop.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              docker pull bkimminich/juice-shop
              docker run -d -p 80:3000 bkimminich/juice-shop
              EOF

  tags = {
    Name = "juice-shop"
  }
}