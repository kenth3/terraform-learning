output "ami" {
  value = data.aws_ami.latest-amazon-linux-image
}

output "ec2_server" {
  value = aws_instance.myapp-server
}
