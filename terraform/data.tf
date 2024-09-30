// aws.tf DATA
data "aws_network_interface" "interface_tags" {
  filter {
    name   = "tag:aws:ecs:serviceName"
    values = [aws_ecs_service.cloud_a_service.name]
  }
}

// xc.tf DATA
data "volterra_http_loadbalancer_state" "cloud_a_lb_state" {
  name      = volterra_http_loadbalancer.cloud_a.name
  namespace = volterra_http_loadbalancer.cloud_a.namespace
}
