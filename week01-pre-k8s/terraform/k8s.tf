
resource "aws_security_group" "k8s_nodes" {
  name        = "k8s_nodes"
  description = "SG for k8s rke cluster"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "general" {
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = aws_security_group.k8s_nodes.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "from_devbox" {
  for_each = {
    ssh     = 22
    kubectl = 6443
  }
  security_group_id            = aws_security_group.k8s_nodes.id
  referenced_security_group_id = var.devbox_sg_id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_egress_rule" "egress_all" {
  security_group_id = aws_security_group.k8s_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


