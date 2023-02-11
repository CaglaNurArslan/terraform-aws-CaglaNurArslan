 /* ## VPC
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

## Launch Config
resource "aws_launch_configuration" "as_conf" {
  name_prefix                 = "terraform-lc-example"
  security_groups             = [aws_security_group.ec2_sg.id]
  #key_name                    = "aws-key"
  image_id                    = "ami-03ededff12e34e59e"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  user_data                   = file("userdata.sh")
  lifecycle {
    create_before_destroy = true
  }
}

## Auto Scaling Group
resource "aws_autoscaling_group" "bar" {
  name                 = "terraform-asg-example"
  vpc_zone_identifier  = [aws_subnet.private-subnet-first.id, aws_subnet.private-subnet-second.id]
  launch_configuration = aws_launch_configuration.as_conf.name
  desired_capacity     = 4
  min_size             = 2
  max_size             = 6
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}

## Load Balancer
resource "aws_lb" "ec2-elb" {
  name               = "ec2-elb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public-subnet-first.id, aws_subnet.public-subnet-second.id]
  tags = {
    Name = "EC2 Load Balancer"
  }
}

## Target Group
resource "aws_lb_target_group" "alb-target-group" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.temp_vpc.id

}

## ELB listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ec2-elb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-target-group.arn
  }
}

## Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.bar.id
  alb_target_group_arn   = aws_lb_target_group.alb-target-group.arn
}

output "alb_dns_name" {
  value = aws_lb.ec2-elb.dns_name
} */