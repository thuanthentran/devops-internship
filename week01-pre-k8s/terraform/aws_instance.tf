data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261108"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "music-ec2"
  public_key = file(pathexpand("~/.ssh/music-ec2.pub"))
}

module "ec2_instance" {
  version = "~> 6.0"
  source  = "terraform-aws-modules/ec2-instance/aws"

  name                   = "deliver-instance"
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  create_security_group  = false
  vpc_security_group_ids = [aws_security_group.web.id, aws_security_group.k8s_nodes.id]
  ami                    = var.ami_id
  key_name               = aws_key_pair.this.key_name
  root_block_device = {
    size = 40
    type = "gp3"
  }
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y docker.io docker-compose-v2
    snap install aws-cli --classic
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    EOF
  subnet_id = data.aws_subnets.default.ids[0]
  metadata_options = {
    http_tokens = "required"
  }
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_eip" "this" {
  instance = module.ec2_instance.id
  domain   = "vpc"
}
