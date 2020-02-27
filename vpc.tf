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

