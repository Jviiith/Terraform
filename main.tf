
# 1. Create a VPC
resource "aws_vpc" "VPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Lab-VPC"
  }
}
# 2. Create an Internet gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.VPC.id

}

# 3. Create a Route Table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Lab-route"
  }
}
# 4. Create a Subnet 
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.VPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Lab-subnet-1"
  }
}
# 5. Associate subnet to Route table 
resource "aws_route_table_association" "route" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route-table.id
}
# 6. Create a Security group to allow ports 22, 80, 443
resource "aws_security_group" "WebSG" {
  name        = "WebSG"
  description = "Allow SSH, HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = {
    Name = "WebSG"
  }
}

# 7. Create a network interface (ENI) with an ip in the subnet that was created (private ip for web server)
resource "aws_network_interface" "Web-ENI" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.WebSG.id]

}

# 8. Create an Linux server and install/enable apache 2

resource "aws_instance" "WebServer1" {
  ami               = "ami-0cf10cdf9fcd62d37"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "ec2-keypair"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.Web-ENI.id
  }

  user_data = <<-EOF
                #!/bin/bash
                yum update
                yum -y install httpd
                chkconfig httpd on
                service httpd start
                EOF

  tags = {
    Name = "Web-Server"
  }
}

# 9. Assaign an elastic IP to the network interface (public ip for web server)
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.Web-ENI.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.igw, aws_instance.WebServer1]
}

output "server_public_ip" {
  value = aws_instance.WebServer1.public_ip
}

output "server_elastic_ip" {
  value = aws_eip.one.public_ip
}
