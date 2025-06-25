terraform {
  required_version = "~> 1.2.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.45"
    }
  }
  backend "s3" {}
}


resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "tf-example"
  }
}


resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "172.16.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "tf-example"
  }
}


resource "aws_internet_gateway" "my_ig" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MY_IGW-1"
  }
}

resource "aws_route_table" "my_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0" ### All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.my_ig.id
  }

  tags = {
    Name = "Public-route"
  }
}

resource "aws_route_table_association" "my_rta" {
  route_table_id = aws_route_table.my_rt.id
  subnet_id      = aws_subnet.my_subnet.id
}

resource "aws_security_group" "my_sg" {
  name   = "my_sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["172.16.10.0/24"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["172.16.10.0/24"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my_sg"
  }

}



resource "aws_instance" "foo" {
  ami           = "ami-0277155c3f0ab2930" # us-east-1
  subnet_id     = aws_subnet.my_subnet.id
  instance_type = "t2.micro"
  #  vpc_security_group_ids = [aws_security_group.my_sg.id]
  security_groups = [aws_security_group.my_sg.id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
EOF                    


  tags = {
    Name = "tf-instance22"
  }


}

output "web_name" {
  value = aws_instance.foo.tags.Name
}

output "web_ip" {
  value = aws_instance.foo.private_ip
}

output "web_pub_ip" {

  value = aws_instance.foo.public_ip
}