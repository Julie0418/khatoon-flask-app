provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ca-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet1_cidr" {
  description = "CIDR block for public subnet 1"
  default     = "10.0.1.0/24"
}


variable "private_subnet1_cidr" {
  description = "CIDR block for private subnet 1"
  default     = "10.0.101.0/24"
}


resource "aws_vpc" "khatoon_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "khatoon-vpc"
  }
}

resource "aws_internet_gateway" "khatoon_igw" {
  vpc_id = aws_vpc.khatoon_vpc.id
  tags = {
    Name = "khatoon-igw"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id            = aws_vpc.khatoon_vpc.id
  cidr_block        = var.public_subnet1_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    Name = "khatoon-public-subnet-1"
  }
}


resource "aws_subnet" "private_subnet1" {
  vpc_id            = aws_vpc.khatoon_vpc.id
  cidr_block        = var.private_subnet1_cidr
  availability_zone = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = false
  tags = {
    Name = "khatoon-private-subnet-1"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.khatoon_vpc.id
  tags = {
    Name = "khatoon-public-rt"
  }
}


resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.khatoon_igw.id
}

resource "aws_route_table_association" "public_subnet1_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat_eip" {
domain                    = "vpc"
}

resource "aws_nat_gateway" "khatoon_natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
  tags = {
    Name = "khatoon-natgw"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.khatoon_vpc.id
  tags = {
    Name = "khatoon-private-rt"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.khatoon_natgw.id
}

resource "aws_route_table_association" "private_subnet1_assoc" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rt.id
}

#############################
# Security Groups
#############################

resource "aws_security_group" "alb_sg" {
  name        = "khatoon-lb-sg"
  description = "Allow HTTP traffic from the internet"
  vpc_id      = aws_vpc.khatoon_vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "khatoon-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.khatoon_vpc.id

  # Allow inbound traffic from the ALB security group
  ingress {
    description      = "Allow traffic from ALB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id] # ALB security group
  }

  # Allow all outbound traffic (e.g., to NAT Gateway or external services)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "khatoon-ecs-sg"
  }
}

#############################
# Application Load Balancer
#############################

resource "aws_lb" "khatoon_alb" {
  name               = "khatoon-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id]

  enable_deletion_protection = false
  tags = {
    Name = "khatoon-alb"
  }
}

resource "aws_lb_target_group" "khatoon_tg" {
  name        = "khatoon-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.khatoon_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  tags = {
    Name = "khatoon-tg"
  }
}

resource "aws_lb_listener" "khatoon_listener" {
  load_balancer_arn = aws_lb.khatoon_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.khatoon_tg.arn
  }
}

