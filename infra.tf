resource "aws_vpc" "rea_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "REA VPC"
  }
}

resource "aws_subnet" "public_us_east_1a" {
  vpc_id     = "${aws_vpc.rea_vpc.id}"
  cidr_block = "10.0.0.0/24"
  
  tags = {
    Name = "Public Subnet us-east-1a"
  }
}

resource "aws_subnet" "public_us_east_1b" {
  vpc_id     = "${aws_vpc.rea_vpc.id}"
  cidr_block = "10.0.1.0/24"
  
  tags = {
    Name = "Public Subnet us-east-1b"
  }
}

resource "aws_internet_gateway" "rea_vpc_igw" {
  vpc_id = "${aws_vpc.rea_vpc.id}"

  tags = {
    Name = "REA VPC - Internet Gateway"
  }
}

resource "aws_route_table" "rea_vpc_public" {
    vpc_id = "${aws_vpc.rea_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.rea_vpc_igw.id}"
    }

    tags = {
        Name = "Public Subnets Route Table for My VPC"
    }
}

resource "aws_route_table_association" "rea_vpc_us_east_1a_public" {
    subnet_id = "${aws_subnet.public_us_east_1a.id}"
    route_table_id = "${aws_route_table.rea_vpc_public.id}"
}

resource "aws_route_table_association" "rea_vpc_us_east_1b_public" {
    subnet_id = "${aws_subnet.public_us_east_1b.id}"
    route_table_id = "${aws_route_table.rea_vpc_public.id}"
}

resource "aws_security_group" "rea_allow_http" {
  name        = "rea_allow_http"
  description = "Allow HTTP"
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
    Name = "Allow HTTP SG"
  }
}

resource "aws_launch_configuration" "appserver" {
  name_prefix = "appserver-"

  #image_id = "ami-0a887e401f7654935" 
  image_id = "ami-09479453c5cde9639"
  instance_type = "t2.micro"

  security_groups = ["${aws_security_group.rea_allow_http.id}"]
  associate_public_ip_address = true
  user_data = "${file("install_nginx.sh")}"

  lifecycle {
    create_before_destroy = true
  }
}

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

resource "aws_autoscaling_group" "rea-web" {
  name = "${aws_launch_configuration.appserver.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 3
  
  health_check_type    = "ELB"
  load_balancers = [
    "${aws_elb.rea_web_elb.id}"
  ]

  launch_configuration = "${aws_launch_configuration.appserver.name}"
 

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity="1Minute"

  vpc_zone_identifier  = ["${aws_subnet.public_us_east_1a.id}", "${aws_subnet.public_us_east_1b.id}"]
  
  # For redeploying without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "appserver"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "rea_up" {
  name = "rea_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.rea-web.name}"
}

resource "aws_cloudwatch_metric_alarm" "rea_cpu_alarm_up" {
  alarm_name = "rea_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.rea-web.name}"
  }

  alarm_description = "Monitor EC2 instance CPU utilization"
  alarm_actions = ["${aws_autoscaling_policy.rea_up.arn}"]
}

resource "aws_autoscaling_policy" "rea_down" {
  name = "rea_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.rea-web.name}"
}

resource "aws_cloudwatch_metric_alarm" "rea_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.rea-web.name}"
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = ["${aws_autoscaling_policy.rea_down.arn}"]
}

output "ELB_IP" {
  value = "${aws_elb.rea_web_elb.dns_name}"
}
