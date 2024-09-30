// TAG THE EXISTING ON-PREM SITE
resource "volterra_modify_site" "tde_seg_ce_vmware_gve" {
  name      = var.on_prem_site
  namespace = "system"
}

// HEALTHCHECK DEFINITION
resource "volterra_healthcheck" "clouds" {
  for_each = tomap({
    cloud_a = {
      name             = "A"
      healthcheck_path = "/"
    }
    cloud_b = {
      name             = "B"
      healthcheck_path = "/app3/index.php"
    }
    cloud_c = {
      name             = "C"
      healthcheck_path = "/api/side_bar.php"
    }
  })
  description         = format("Healthcheck for testing SEG Cloud %s's origin pools", each.value.name)
  name                = format("seg-cloud-%s-healthcheck", lower(each.value.name))
  namespace           = var.namespace
  timeout             = 3
  healthy_threshold   = 3
  unhealthy_threshold = 1
  interval            = 60
  http_health_check {
    path = each.value.healthcheck_path
  }
}

// CLOUD-B and CLOUD-C ORIGIN POOL DEFINITION
resource "volterra_origin_pool" "cloud_b_c" {
  for_each = tomap({
    cloud_b = {
      name = "B"
      port = 8080
    }
    cloud_c = {
      name = "C"
      port = 8080
    }
  })
  description            = format("Origin pool for the Cloud %s services on premise", each.value.name)
  name                   = format("seg-cloud-%s-op", lower(each.value.name))
  namespace              = var.namespace
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  port                   = each.value.port
  no_tls                 = true

  healthcheck {
    name      = volterra_healthcheck.clouds[each.key].name
    namespace = volterra_healthcheck.clouds[each.key].namespace
    tenant    = var.tenant
  }

  origin_servers {
    k8s_service {
      vk8s_networks = true
      service_name  = format("seg-vk8s-workload-cloud-%s.seg360-2024-demo", lower(each.value.name))
      site_locator {
        site {
          name      = var.on_prem_site
          namespace = "system"
          tenant    = var.tenant
        }
      }
    }
  }
}

// CLOUD-A ORIGIN POOL DEFINITION
resource "volterra_origin_pool" "cloud_a" {
  description            = "Origin pool for the Cloud A's frontend service on AWS"
  name                   = "seg-cloud-a-op"
  namespace              = var.namespace
  endpoint_selection     = "LOCAL_PREFERRED"
  loadbalancer_algorithm = "LB_OVERRIDE"
  port                   = 8080
  no_tls                 = true

  healthcheck {
    name      = volterra_healthcheck.clouds["cloud_a"].name
    namespace = volterra_healthcheck.clouds["cloud_a"].namespace
    tenant    = var.tenant
  }

  origin_servers {
    private_ip {
      ip             = local.cloud_a_service_private_ip
      inside_network = true
      site_locator {
        site {
          name      = volterra_aws_vpc_site.cloud_a_site.name
          namespace = "system"
          tenant    = var.tenant
        }
      }
    }
  }
}

// SERVICE POLICY FOR ALLOWING ONLY E-XPERT WAN IP
resource "volterra_service_policy" "allow_e_xpert_wan" {
  description = "Policy to allow connections from internet only with e-Xpert owned WAN IPs"
  name        = "seg-allow-e-xpert-wan"
  namespace   = var.namespace
  algo        = "FIRST_MATCH"
  any_server  = true
  allow_list {
    prefix_list {
      prefixes      = ["46.14.179.0/27", "83.166.158.32/27", "81.63.137.43/32"]
      ipv6_prefixes = []
    }
    default_action_next_policy = true
  }
}

// WAF CONFIGURATION
resource "volterra_app_firewall" "seg_waf_config" {
  description = "Basic WAF config for SEG demo application"
  name        = "seg-waf-config"
  namespace   = var.namespace
  blocking    = true

  // defaults
  allow_all_response_codes   = true
  use_default_blocking_page  = true
  default_bot_setting        = true
  default_detection_settings = true

  custom_anonymization {
    anonymization_config {
      query_parameter {
        // Masks the Signature query parameter of SAML Redirect
        query_param_name = "Signature"
      }
    }
  }
}

// LOAD BALANCER FOR INTERNAL SERVICE ON-PREM ADVERTISED ON AWS
resource "volterra_http_loadbalancer" "cloud_b_c" {
  description = "Load balancer for Cloud B and Cloud C's services advertised on Cloud A."
  name        = "seg-cloud-b-c-http-lb"
  namespace   = var.namespace
  domains     = [local.cloud_b_domain, local.cloud_c_domain]

  # despite being defaults, all these must be set, otherwise trigger change detection
  service_policies_from_namespace  = true
  disable_api_definition           = true
  disable_api_discovery            = true
  disable_rate_limit               = true
  disable_trust_client_ip_headers  = true
  l7_ddos_action_default           = true
  no_challenge                     = true
  round_robin                      = true
  user_id_client_ip                = true
  disable_malicious_user_detection = true

  app_firewall {
    name      = volterra_app_firewall.seg_waf_config.name
    namespace = volterra_app_firewall.seg_waf_config.namespace
    tenant    = var.tenant
  }

  http {
    # not supported for site advertised LB. Done manually but with TF
    # dns_volterra_managed = true
    port = 80
  }

  routes {
    simple_route {
      auto_host_rewrite = true
      http_method       = "ANY"
      origin_pools {
        pool {
          name      = volterra_origin_pool.cloud_b_c["cloud_b"].name
          namespace = volterra_origin_pool.cloud_b_c["cloud_b"].namespace
          tenant    = var.tenant
        }
        weight   = 1
        priority = 1
      }
      path {
        prefix = "/app3/"
      }
    }
  }

  routes {
    simple_route {
      auto_host_rewrite = true
      http_method       = "ANY"
      origin_pools {
        pool {
          name      = volterra_origin_pool.cloud_b_c["cloud_c"].name
          namespace = volterra_origin_pool.cloud_b_c["cloud_c"].namespace
          tenant    = var.tenant
        }
        weight   = 1
        priority = 1
      }
      path {
        prefix = "/api/"
      }
    }
  }


  advertise_custom {
    advertise_where {
      use_default_port = true
      site {
        network = "SITE_NETWORK_INSIDE"
        site {
          name      = volterra_aws_vpc_site.cloud_a_site.name
          namespace = volterra_aws_vpc_site.cloud_a_site.namespace
          tenant    = var.tenant
        }
      }
    }
  }
}

// CLIENT FACING HTTP LOAD BALANCER DEFINITION
resource "volterra_http_loadbalancer" "cloud_a" {
  description = "Client facing load balancer for SEG360 demo application."
  name        = "seg-cloud-a-http-lb"
  namespace   = var.namespace
  domains     = [local.app_fqdn]

  # despite being defaults, all these must be set, otherwise trigger change detection
  advertise_on_public_default_vip  = true
  disable_api_definition           = true
  disable_api_discovery            = true
  disable_rate_limit               = true
  disable_trust_client_ip_headers  = true
  l7_ddos_action_default           = true
  no_challenge                     = true
  round_robin                      = true
  user_id_client_ip                = true
  disable_malicious_user_detection = true

  app_firewall {
    name      = volterra_app_firewall.seg_waf_config.name
    namespace = volterra_app_firewall.seg_waf_config.namespace
    tenant    = var.tenant
  }

  https_auto_cert {
    no_mtls               = true
    enable_path_normalize = true
    port                  = 443
  }

  more_option {
    request_headers_to_add {
      name  = "X-Forwarded-Host"
      value = local.app_fqdn
    }
  }
  default_route_pools {
    pool {
      name      = volterra_origin_pool.cloud_a.name
      namespace = volterra_origin_pool.cloud_a.namespace
      tenant    = var.tenant
    }
    # must be set as default value is 0 and disables the pool
    weight   = 1
    priority = 1
  }

  active_service_policies {
    policies {
      name      = volterra_service_policy.allow_e_xpert_wan.name
      namespace = volterra_service_policy.allow_e_xpert_wan.namespace
      tenant    = var.tenant
    }
  }
}
