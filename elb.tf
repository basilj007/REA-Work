resource "aws_security_group" "rea_elb_http" {
  name        = "rea_elb_http"
  description = "Allow HTTP through ELB"
  vpc_id = "${aws_vpc.rea_vpc.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP through ELB SG"
  }
}

resource "aws_elb" "rea_web_elb" {
  name = "rea-web-elb"
  security_groups = [
    "${aws_security_group.rea_elb_http.id}"
  ]
  subnets = [
    "${aws_subnet.public_us_east_1a.id}",
    "${aws_subnet.public_us_east_1b.id}"
  ]
  cross_zone_load_balancing   = true
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "TCP:80"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

