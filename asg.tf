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

