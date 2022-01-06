provider "aws" {
  region = "us-east-1"
  # access_key = ""  do we need this?  can't I just use my local credentials?
  # secret_key = ""
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
variable "private_key_location" {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

# note that even though this IGW needs to be created first before 
# it can be referenced by the above route table, TF is smart enough
# to know the necessary order to create components, so this out-of-order
# declaration works (though I would still rather declare this above)
resource "aws_internet_gateway" "myapp-internet-gateway" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

# To create a new main/default route table and subnet associations,
# and therefore replace the one created by AWS, 
# UNcomment this resource
resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    # by default, the entry that routes internal traffic within the VPC is already
    # created, so we only need to add our further desired routes
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-internet-gateway.id
  }
  tags = {
    Name = "${var.env_prefix}-main-rtb"
  }
}

# add a new security group with rules that allow us to SSH
# and browse nginx:  aws_security_group

# or configure the existing default security group: aws_defaultsecurity_group
resource "aws_default_security_group" "default-sg" {
  # name   = "myapp-sg" - uncomment if new sg
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    # from and to define a range of ports to be opened
    # in this case, we only want 1 port, so from and to are the same
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # define which IP addresses are allowed to access port range
    # done via a list of cidr ranges
    # in this case, this is my personal IP address
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outgoing can include installations or docker containers, etc.
  # so we won't restrict this
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-default-sg"
  }
}

# retrieve the id of the latest amazon linux ami
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "server-key"
  public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type

  # make sure it's created in our new vpc subnet and sg.
  # if not specified, the instance will be created in the
  # default VPC and security groups.
  subnet_id              = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone      = var.avail_zone

  # this allows us to hit the server via ssh or http
  associate_public_ip_address = true

  # associate the key pair we created in AWS console with this
  # ec2 instance
  key_name = aws_key_pair.ssh-key.key_name

  # NOTE - TF does NOT recommend using provisioners
  # this is provided only as an example
  connection {
    type        = "ssh"          # (either ssh or winrm)
    host        = self.public_ip # can use "self" when within the resource
    user        = "ec2-user"
    private_key = file(var.private_key_location)
  }

  provisioner "file" {
    source      = "entry-script.sh"
    destination = "/home/ec2-user/entry-script.sh"
  }

  provisioner "remote-exec" {
    script = file("entry-script.sh")
    # inline = [
    #   "export ENV=dev",
    #   "mkdir newdir",
    # ]
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip}"
  }

  tags = {
    Name = "${var.env_prefix}-server"
  }
}

# To use AWS' default created route table and subnet associations,
# keep these lines commented:

# resource "aws_route_table" "myapp-route-table" {
#   vpc_id = aws_vpc.myapp-vpc.id
#   route {
#     # by default, the entry that routes internal traffic within the VPC is already
#     # created, so we only need to add our further desired routes
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.myapp-internet-gateway.id
#   }
#   tags = {
#     Name = "${var.env_prefix}-rtb"
#   }
# }

# this associates our new route table with our new subnet (if this isn't done 
# here explicitly, our new subnet will automatically be added to the MAIN route 
# table in our VPC, not our new route table)
# resource "aws_route_table_association" "a-rtb-subnet" {
#   subnet_id      = aws_subnet.myapp-subnet-1.id
#   route_table_id = aws_route_table.myapp-route-table.id
# }

# remember: to find available attributes of the objects,
# can do a "terraform plan"
output "vpc-id" {
  value = aws_vpc.myapp-vpc.id
}

output "subnet-id" {
  value = aws_subnet.myapp-subnet-1.id
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}
