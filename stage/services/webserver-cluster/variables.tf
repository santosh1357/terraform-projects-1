#refernce of variable - var.<varName>
variable "server_port" {
  description = "Incoming port for the web server"
  type = number
  default = 8080
}
# to ge the dns name of the public LB
output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}


