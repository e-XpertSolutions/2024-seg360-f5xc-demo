// aws.tf OUTPUTS
output "ecs_container_private_ip" {
  value = local.cloud_a_service_private_ip
}

output "aws_site_creation_tf_output" {
  value = volterra_tf_params_action.apply_aws_vpc.tf_output
}

output "aws_customer_edge_private_ip_on_aws" {
  value = local.aws_ce_instance_private_ip
}

// xc.tf OUTPUTS
output "lb_virtual_host" {
  value = volterra_http_loadbalancer.cloud_a.cname
}

output "lb_state" {
  value = data.volterra_http_loadbalancer_state.cloud_a_lb_state
}
