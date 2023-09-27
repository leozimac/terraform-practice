terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 4.16"
      }
    }

  required_version = ">= 1.2.0"
}

provider "aws"{
    region = "us-east-1"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "dev"
  }
}

resource "aws_internet_gateway" "dev_gw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev_gw"
  }
}

resource "aws_route_table" "dev_route_table" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_gw.id
  }

  tags = {
    Name = "dev_route_table"
  }
}

resource "aws_subnet" "dev_subnet" {
  vpc_id = aws_vpc.dev_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "dev_subnet"
  }
}

resource "aws_route_table_association" "dev_rta" {
  subnet_id = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_route_table.id
}

resource "aws_security_group" "dev_allow_web" {
  name = "allow_web_traffic"
  description = ""
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 2
    to_port = 2
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web_server_nic" {
  subnet_id = aws_subnet.dev_subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.dev_allow_web.id]

}

resource "aws_eip" "dev_eip" {
  vpc = true
  network_interface = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.dev_gw]
}

resource "aws_instance" "dev_web_server_instance" {
  ami = "ami-024e6efaf93d85776"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo dev web server > /var/www/html/index.html'
              EOF
  
  tags = {
    Name = "dev-web-server"
  }
}