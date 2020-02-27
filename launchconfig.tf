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

