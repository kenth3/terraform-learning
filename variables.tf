variable "vpc_cidr_block" {
  type = string
}
variable "subnet_cidr_blocks" {
  type = list(string)
}
variable "avail_zones" {
  type = list(string)
}

variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
variable "image_name" {}
