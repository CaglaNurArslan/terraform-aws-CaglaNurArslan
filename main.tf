## VPC
resource "aws_vpc" "temp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "web-server-vpc"
  }
}

## Public Subnet First
resource "aws_subnet" "public-subnet-first" {
  vpc_id            = aws_vpc.temp_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public Subnet First"
  }
}

## Public Subnet Second
resource "aws_subnet" "public-subnet-second" {
  vpc_id            = aws_vpc.temp_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Public Subnet Second"
  }
}

## Private Subnet First
resource "aws_subnet" "private-subnet-first" {
  vpc_id            = aws_vpc.temp_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Private Subnet First"
  }
}

## Private Subnet Second
resource "aws_subnet" "private-subnet-second" {
  vpc_id            = aws_vpc.temp_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Private Subnet Second"
  }
}

## Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.temp_vpc.id
  tags = {
    Name = "Internet Gateway"
  }
}

## Elastic IP
resource "aws_eip" "eip_first" {
  vpc = true
}
resource "aws_eip" "eip_second" {
  vpc = true
}


## NAT Gateway First
resource "aws_nat_gateway" "nat-gateway-first" {
  allocation_id = aws_eip.eip_first.id
  subnet_id     = aws_subnet.public-subnet-first.id
  depends_on    = [aws_internet_gateway.internet-gateway]
  tags = {
    Name = "Nat Gateway First"
  }
}

## NAT Gateway Second
resource "aws_nat_gateway" "nat-gateway-second" {
  allocation_id = aws_eip.eip_second.id
  subnet_id     = aws_subnet.public-subnet-second.id
  depends_on    = [aws_internet_gateway.internet-gateway]
  tags = {
    Name = "Nat Gateway Second"
  }
}

## Public Route Table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.temp_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
  tags = {
    Name = "Public Route Table"
  }
}

## Private Route Table First
resource "aws_route_table" "private-rt-first" {
  vpc_id = aws_vpc.temp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gateway-first.id
  }

  tags = {
    Name = "Private Route Table First"
  }
}

## Private Route Table Second
resource "aws_route_table" "private-rt-second" {
  vpc_id = aws_vpc.temp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gateway-second.id
  }

  tags = {
    Name = "Private Route Table Second"
  }
}

## Public RT Associated First
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet-first.id
  route_table_id = aws_route_table.public-rt.id
}
## Public RT Associated Second
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public-subnet-second.id
  route_table_id = aws_route_table.public-rt.id
}

## Private RT Associated First
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private-subnet-first.id
  route_table_id = aws_route_table.private-rt-first.id
}
## Private RT Associated Second
resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.private-subnet-second.id
  route_table_id = aws_route_table.private-rt-second.id
}

## Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "alb-allow-traffic"
  description = "Allow traffic for ALB"
  vpc_id      = aws_vpc.temp_vpc.id
  ingress {
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  ingress {
    description = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow Traffic for ALB"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-allow-traffic"
  description = "Allow traffic for EC2"
  vpc_id      = aws_vpc.temp_vpc.id
  ingress {
    description     = "HTTP"
    security_groups = [aws_security_group.alb_sg.id]
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
  }
  ingress {
    description     = "SSH"
    security_groups = [aws_security_group.alb_sg.id]
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow Traffic for EC2"
  }
}