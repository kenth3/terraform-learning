output "vpc-id" {
  value = module.vpc.vpc_id
}

output "aws_ami_id" {
  value = module.myapp-server.ami.id
}

output "ec2_public_ip" {
  value = module.myapp-server.ec2_server.public_ip
}
