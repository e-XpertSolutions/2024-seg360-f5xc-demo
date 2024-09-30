locals {
  app_fqdn                   = format("%s.%s", var.app_subdomain, var.app_domain)
  cloud_b_domain             = format("%s.%s", var.cloud_b_subdomain, local.app_fqdn)
  cloud_c_domain             = format("%s.%s", var.cloud_c_subdomain, local.app_fqdn)
  cloud_a_service_private_ip = data.aws_network_interface.interface_tags.private_ip
  # retrieves the aws workload subnet id created from the tf_output returned by aws to xc.
  workload_subnet_id         = jsondecode(regexall("subnet_info = (.*)", volterra_tf_params_action.apply_aws_vpc.tf_output)[0][0])[0].workload_subnet.id
  # catches the created vpc id from the tf_output returned during the site creation by xc
  volt_vpc_id                = regexall("volt_vpc_id = \"(.*)\"", volterra_tf_params_action.apply_aws_vpc.tf_output)[0][0]
  aws_ce_instance_private_ip = jsondecode(regexall("controller_dp_private_sli_ips = (.*)", volterra_tf_params_action.apply_aws_vpc.tf_output)[0][0])[0]
}
