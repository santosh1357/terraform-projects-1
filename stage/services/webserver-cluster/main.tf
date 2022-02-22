#Single WSever is single pofailure, ASG can monitor and replace failed nodes as well as scale on load
#Create ASG by first creating a resource (aws_launch_config..similar to aws_instance)
#the second resorce we create is tje ASG itself (aws_autoscaling_group) which refers to res-1(aws_launch_con..)

provider "aws" {
    region = "ap-south-1"
}
terraform {
    backend "s3" {
        key = "stage/services/webserver-cluster/terraform.tfstate"
        bucket = "leaning-projects-1"
        region = "ap-south-1"     
        dynamodb_table = "learning-projects-locks"
        encrypt = true
    }
}

data "aws_vpc" "default" {
    default = true
}
data "aws_subnet_ids" "defVpcSubnets" {
    vpc_id = data.aws_vpc.default.id
}
resource "aws_launch_configuration" "webserver_asg" {
    image_id = "ami-00d3938d52d531b8e"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.webServerSG-1.id]
#subnets mandatory param for launch config, each subnet lives in isolated AZ
#giving multiple subnets is way to achieve datacenter redundancy
#rather than hardcoding we use DATA Sources to define subnets to make code more portable
#data sources are ways to query provider APIs for info like subnet data, vpc data, ip data, ami ids etc 
#data "provider_type" "name" {
    #[CONFIG...] - filter we apply on values return from provider api
#} data.provider_type.name.attributre [reference the returned data]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World " > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF
    #Launch configs are immutable, so any change in them will force change in ASG
    #change terraform default lifecycle policy (destroy then create) using lifecycle hooks
    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_autoscaling_group" "asg_webserver" {
    launch_configuration = aws_launch_configuration.webserver_asg.name
# you can pull the subnet IDs out of the aws_subnet_ids
# data source and tell your ASG to use those subnets via the (somewhat
# oddly named) vpc_zone_identifier argument:
    vpc_zone_identifier = data.aws_subnet_ids.defVpcSubnets.ids
    min_size = 2
    max_size = 10
    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"
    tag  {
        key = "Name"
        value = "asg-webserver"
        propagate_at_launch = true

    }
}
#By default AWS does not allow any in/out traffic from ec2
#create a security group resource to allow ec2 vms accept ingress traffic on port
resource "aws_security_group" "webServerSG-1" {
  name = "webServerSG-1"
  ingress {
      from_port = var.server_port
      to_port = var.server_port
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}
### Load Balancer Components ###
resource "aws_lb" "example" {
    name = "terraform-asg-example"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.defVpcSubnets.ids
    security_groups = [aws_security_group.alb.id]
}
#Listener for LB to enable LB to listen on port 80 and http
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = 80
    protocol = "HTTP"
# By default, return a simple 404 page
    default_action {
        type = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = 404
        }
    }
}
#sec grp for LB to open port 80
resource "aws_security_group" "alb" {
name = "terraform-example-alb"
# Allow inbound HTTP requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
# Allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
## target group acts as  intermediate or joining bond between LB and ASG
resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}
#listenerRule binding force to listener and target Group
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    condition {
        path_pattern {
            values = ["*"]
        }
    }
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}


