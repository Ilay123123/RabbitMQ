provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "rabbitmq_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "rabbitmq-cluster-vpc"
  }
}

resource "aws_subnet" "rabbitmq_subnet" {
  vpc_id            = aws_vpc.rabbitmq_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "rabbitmq-cluster-subnet"
  }
}

# Add Internet Gateway
resource "aws_internet_gateway" "rabbitmq_igw" {
  vpc_id = aws_vpc.rabbitmq_vpc.id

  tags = {
    Name = "rabbitmq-igw"
  }
}

# Route table
resource "aws_route_table" "rabbitmq_rt" {
  vpc_id = aws_vpc.rabbitmq_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rabbitmq_igw.id
  }
  tags = {
    name = "rabbitmq-rt"
  }
}

resource "aws_route_table_association" "rabbitmq-rta" {
  subnet_id = aws_subnet.rabbitmq_subnet.id
  route_table_id = aws_route_table.rabbitmq_rt.id
}



# Security Group
resource "aws_security_group" "rabbitmq_sg" {
  name        = "rabbitmq-cluster-sg"
  description = "Security group for RabbitMQ cluster"
  vpc_id      = aws_vpc.rabbitmq_vpc.id

  # RabbitMQ ports
  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Clustering ports
  ingress {
    from_port   = 25672
    to_port     = 25672
    protocol    = "tcp"
    self        = true
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "rabbitmq_template" {
  name_prefix   = "rabbitmq-node"
  image_id      = var.ami_id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.rabbitmq_sg.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Install Docker
              apt-get update
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker

              curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Create Docker Compose file
              cat > /root/docker-compose.yml <<'EOYAML'
              version: '3.7'
              services:
                rabbitmq:
                  image: rabbitmq:3.9-management
                  hostname: "rabbitmq"
                  environment:
                    - RABBITMQ_ERLANG_COOKIE=SWQOKODSQALRPCLNMEQG
                    - RABBITMQ_DEFAULT_USER=admin
                    - RABBITMQ_DEFAULT_PASS=admin123
                    - AWS_ACCESS_KEY_ID=AKIAS2VS4VHWNDWOGU7H
                    - AWS_SECRET_ACCESS_KEY=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
                    - AWS_DEFAULT_REGION=us-east-1
                  ports:
                    - 5672:5672
                    - 15672:15672
                    - 25672:25672
                  volumes:
                    - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf
              EOYAML

              # Create RabbitMQ config
              cat > /root/rabbitmq.conf <<'EOL'
              cluster_formation.peer_discovery_backend = rabbit_peer_discovery_aws
              cluster_formation.aws.region = ${var.aws_region}
              cluster_formation.aws.use_autoscaling_group = true
              cluster_formation.aws.instance_tags.Role = rabbitmq
              EOL

              # Start RabbitMQ
              cd /root && docker-compose up -d
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Role = "rabbitmq"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "rabbitmq_asg" {
  desired_capacity    = var.cluster_size
  max_size           = var.max_size
  min_size           = var.min_size
  target_group_arns  = [aws_lb_target_group.rabbitmq_tg.arn]
  vpc_zone_identifier = [aws_subnet.rabbitmq_subnet.id]

  launch_template {
    id      = aws_launch_template.rabbitmq_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "rabbitmq"
    propagate_at_launch = true
  }
}

# Load Balancer
resource "aws_lb" "rabbitmq_lb" {
  name               = "rabbitmq-cluster-lb"
  internal           = false
  load_balancer_type = "network"
  subnets           = [aws_subnet.rabbitmq_subnet.id]
}

resource "aws_lb_target_group" "rabbitmq_tg" {
  name     = "rabbitmq-cluster-tg"
  port     = 5672
  protocol = "TCP"
  vpc_id   = aws_vpc.rabbitmq_vpc.id
}

resource "aws_lb_listener" "rabbitmq" {
  load_balancer_arn = aws_lb.rabbitmq_lb.arn
  port              = 5672
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbitmq_tg.arn
  }
}