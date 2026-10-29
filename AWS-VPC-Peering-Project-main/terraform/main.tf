terraform {
  required_version = ">= 1.0"
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

# Dynamic Availability Zone lookup (uses first available AZ in target region)
data "aws_availability_zones" "available" {
  state = "available"
}

# ==========================================
# 1. VPC A & Networking (10.10.0.0/16)
# ==========================================
resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "ewb-vpc-a"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags = {
    Name    = "ewb-igw-a"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name    = "ewb-a-public"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.10.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name    = "ewb-a-private"
    Project = "EWB-VPC-Peering"
  }
}

# ==========================================
# 2. VPC B & Networking (10.20.0.0/16)
# ==========================================
resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "ewb-vpc-b"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name    = "ewb-b-private"
    Project = "EWB-VPC-Peering"
  }
}

# ==========================================
# 3. VPC Peering Connection
# ==========================================
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true
  tags = {
    Name    = "ewb-a-b-peer"
    Project = "EWB-VPC-Peering"
  }
}

# ==========================================
# 4. Route Tables & Peering Routes
# ==========================================
# Public Route Table (VPC A)
resource "aws_route_table" "rt_a_public" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }

  route {
    cidr_block                = "10.20.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

  tags = {
    Name    = "ewb-rt-a-public"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_route_table_association" "rta_public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.rt_a_public.id
}

# Private Route Table (VPC A)
resource "aws_route_table" "rt_a_private" {
  vpc_id = aws_vpc.vpc_a.id

  route {
    cidr_block                = "10.20.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

  tags = {
    Name    = "ewb-rt-a-private"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_route_table_association" "rta_private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.rt_a_private.id
}

# Private Route Table (VPC B)
resource "aws_route_table" "rt_b_private" {
  vpc_id = aws_vpc.vpc_b.id

  route {
    cidr_block                = "10.10.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }

  tags = {
    Name    = "ewb-rt-b-private"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_route_table_association" "rta_private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.rt_b_private.id
}

# ==========================================
# 5. Security Groups
# ==========================================
resource "aws_security_group" "sg_bastion" {
  name        = "ewb-sg-bastion"
  description = "Security group for Bastion jump host in VPC A"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH administrative access from trusted admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ewb-sg-bastion"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_security_group" "sg_app_a" {
  name        = "ewb-sg-app-a"
  description = "Security group for App-A in VPC A"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "SSH from Bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-B private IP over peering"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.20.1.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ewb-sg-app-a"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_security_group" "sg_app_b" {
  name        = "ewb-sg-app-b"
  description = "Security group for App-B in VPC B"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    description = "SSH from Bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }

  ingress {
    description = "ICMP Echo Request from App-A private IP over peering"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.10.2.10/32"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "ewb-sg-app-b"
    Project = "EWB-VPC-Peering"
  }
}

# ==========================================
# 6. AMI & EC2 Compute Instances
# ==========================================
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_a.id
  private_ip                  = "10.10.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_bastion.id]

  tags = {
    Name    = "ewb-bastion"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.private_a.id
  private_ip                  = "10.10.2.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_a.id]

  tags = {
    Name    = "ewb-app-a"
    Project = "EWB-VPC-Peering"
  }
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.private_b.id
  private_ip                  = "10.20.1.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.sg_app_b.id]

  tags = {
    Name    = "ewb-app-b"
    Project = "EWB-VPC-Peering"
  }
}
