resource "aws_route53_zone" "prod" {
  name = "lab.${var.domain}"
}
resource "aws_route53_record" "app" {
  for_each = toset(["app", "node"])
  zone_id  = aws_route53_zone.prod.zone_id
  name     = "${each.key}.${aws_route53_zone.prod.name}"
  type     = "A"
  ttl      = 300
  records  = [aws_eip.this.public_ip]
}