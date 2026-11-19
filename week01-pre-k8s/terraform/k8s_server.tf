module "k8s_instance" {
  version = "~> 6.0"
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "rke2-server"

  instance_type          = "m7i-flex.large"
  key_name               = aws_key_pair.this.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  ami                    = var.ami_id
  create_security_group  = false

  user_data = <<-EOF
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    apt update -y
    apt install -y open-iscsi nfs-common
    systemctl enable open-iscsi
    systemctl start open-iscsi
    EOF
  root_block_device = {
    size = 40
    type = "gp3"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
