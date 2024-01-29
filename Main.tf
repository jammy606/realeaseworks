terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.33.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "healthtech_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Department = "prod"
  }
}

resource "aws_internet_gateway" "healthtech_igw" {
  vpc_id = aws_vpc.healthtech_vpc.id

  tags = {
    Department = "prod"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.healthtech_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "eu-west-2"

  map_public_ip_on_launch = true

  tags = {
    Department = "prod"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.healthtech_vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "eu-west-2"

  tags = {
    Department = "prod"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.healthtech_vpc.id

  route {
    cidr_block = "10.10.3.0/24"
    gateway_id = aws_internet_gateway.healthtech_igw.id
  }

  tags = {
    Department = "prod"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_instance" "bastion_host" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  key_name = "example key pair name"

  vpc_security_group_ids = [aws_security_group.bastion_host.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Department = "prod"
  }
}

resource "aws_security_group" "bastion_security_group" {
  name        = "bastion-sg"
  description = "Security group for bastion host"

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

resource "aws_db_instance" "healthtech_rds" {
  identifier          = "healthtech-rds"
  allocated_storage   = 20
  engine              = "mysql"
  instance_class      = "db.t2.micro"
  username            = "admin"
  password            = "password"
  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  vpc_security_group_ids = [aws_security_group.healthtech_rds.id]

  subnet_group_name = aws_db_subnet_group.private_subnet.id
  tags = {
    Department = "prod"
  }
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS instance"

  ingress {
    from_port          = 3306
    to_port            = 3306
    protocol           = "tcp"
  }
}

resource "aws_db_subnet_group" "healthtecg_db_subnet_group" {
  name       = "healthtechdb"
  subnet_ids = [aws_subnet.private_subnet.id]

  tags = {
    Department = "prod"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.healthtech_rds.endpoint
}
