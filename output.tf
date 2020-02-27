output "ELB_IP" {
  value = "${aws_elb.rea_web_elb.dns_name}"
}
