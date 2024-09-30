// F5XC's credentials for controlling AWS
resource "volterra_cloud_credentials" "aws_cred" {
  name      = "seg-aws-creds"
  namespace = "system"
  aws_secret_key {
    access_key = var.aws_f5xc_access_key
    secret_key {
      blindfold_secret_info {
        location = format("string:///%s", var.aws_f5xc_secret_key_blindfolded)
      }
    }
  }
}

// AWS Site's definitions
resource "volterra_aws_vpc_site" "cloud_a_site" {
  name                    = "seg-cloud-a-site"
  description             = "Site deployed on AWS for testing the SEG360 demo"
  namespace               = "system"
  aws_region              = var.aws_region
  block_all_services      = true
  direct_connect_disabled = true
  disk_size               = 0
  egress_gateway_default  = true
  instance_type           = "t3.xlarge"
  disable_internet_vip    = true
  f5xc_security_group     = true
  ssh_key                 = var.aws_ssh_key
  no_worker_nodes         = true

  vpc {
    new_vpc {
      autogenerate = true
      primary_ipv4 = var.aws_vpc_cidr
    }
  }

  ingress_egress_gw {
    aws_certified_hw         = "aws-byol-multi-nic-voltmesh"
    no_dc_cluster_group      = true
    no_forward_proxy         = true
    no_global_network        = true
    no_inside_static_routes  = true
    no_network_policy        = true
    no_outside_static_routes = true
    sm_connection_public_ip  = true
    az_nodes {
      aws_az_name            = var.aws_az
      reserved_inside_subnet = true
      outside_subnet {
        subnet_param {
          ipv4 = "10.20.20.0/24"
        }
      }
      workload_subnet {
        subnet_param {
          ipv4 = "10.20.10.0/24"
        }
      }
    }
  }

  aws_cred {
    name      = volterra_cloud_credentials.aws_cred.name
    namespace = "system"
    tenant    = var.tenant
  }

}

// ACTION TO PERFORM FOR SITE DEFINITION
resource "volterra_tf_params_action" "apply_aws_vpc" {
  site_name       = volterra_aws_vpc_site.cloud_a_site.name
  site_kind       = "aws_vpc_site"
  action          = "apply"
  wait_for_action = true
}

// DNS RECORDS FOR INTERNAL PRIVATE LOAD BALANCERS
// These need to be defined before launching the services.
// Nginx expects to resolve the domains for the templated config
resource "volterra_dns_zone" "cloud_b_c_records" {
  for_each = tomap({
    cloud_b = {
      name = local.cloud_b_domain
    }
    cloud_c = {
      name = local.cloud_c_domain
    }
  })
  name      = each.value.name
  namespace = "system"

  primary {
    dnssec_mode {
      # the enable{} block works but triggers change detection
      disable = false
    }
    default_rr_set_group {
      ttl = "120"
      a_record {
        name   = ""
        values = [local.aws_ce_instance_private_ip]
      }
    }
  }
}

// DEFINES THE WEBAPP TASK AND SERVICE
resource "aws_ecs_task_definition" "cloud_a_task" {
  family                   = "seg-cloud-a-tasks"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::699300912331:role/ecsTaskExecutionRole"
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "MainApp"
  }
  volume {
    name = "files"
  }
  container_definitions = jsonencode([
    {
      name      = "reverse-proxy"
      image     = var.aws_reverse_proxy_image
      essential = true
      cpu       = 0
      portMappings = [{
        name          = "reverse-proxy-8080-tcp"
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
        appProtocol   = "http"
      }]
      environment = [
        {
          name  = "CLOUD_B_DOMAIN"
          value = volterra_dns_zone.cloud_b_c_records["cloud_b"].name
        },
        {
          name = "CLOUD_C_DOMAIN"
        value = volterra_dns_zone.cloud_b_c_records["cloud_c"].name }
      ]
      dependsOn = [
        {
          containerName = "frontend"
          condition     = "START"
          }, {
          containerName = "backend"
          condition     = "START"
        }
      ]
    },
    {
      name      = "frontend"
      image     = var.aws_frontend_image
      essential = true
      cpu       = 0
      portMappings = [{
        name          = "frontend-8081-tcp"
        containerPort = 8081
        hostPort      = 8081
        protocol      = "tcp"
        appProtocol   = "http"
      }]
      mountPoints = [
        {
          sourceVolume  = "MainApp"
          containerPath = "/usr/share/nginx/html/MainApp/"
          readOnly      = false
        }
      ]
      dependsOn = [
        {
          containerName = "fastcgi"
          condition     = "START"
        }
      ]
    },
    {
      name      = "backend"
      image     = var.aws_backend_image
      essential = true
      cpu       = 0
      portMappings = [{
        name          = "backend-8082-tcp"
        containerPort = 8082
        hostPort      = 8082
        protocol      = "tcp"
        appProtocol   = "http"
      }]
      mountPoints = [
        {
          sourceVolume  = "files"
          containerPath = "/usr/share/nginx/html/backend/files/"
          readOnly      = false
        }
      ]
      dependsOn = [
        {
          containerName = "fastcgi"
          condition     = "START"
        }
      ]
    },
    {
      name      = "fastcgi"
      image     = var.aws_fastcgi_image
      essential = true
      cpu       = 0
      portMappings = [{
        name          = "fastcgi-9000-tcp"
        containerPort = 9000
        hostPort      = 9000
        protocol      = "tcp"
      }]
      mountPoints = [
        {
          sourceVolume  = "MainApp"
          containerPath = "/usr/share/nginx/html/MainApp/"
          readOnly      = false
        },
        {
          sourceVolume  = "files"
          containerPath = "/usr/share/nginx/html/backend/files/"
          readOnly      = false
        }
      ]
    }
  ])
}

resource "aws_ecs_cluster" "cloud_a_cluster" {
  name = "seg-cloud-a-cluster"
}

resource "aws_security_group" "allow_all" {
  name        = "seg-allow-all-sg"
  description = "Allow all inbound traffic from VPC and all outbound traffic"
  vpc_id      = local.volt_vpc_id
  # must keep this in-line definition (and not use aws_vpc_security_group_*gress_rule). 
  # Otherwise, dependencies may create the aws_ecs_service before the  
  # aws_vpc_security_group_*gress_rule and prevent the container from being pulled
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.aws_vpc_cidr]
  }
}

resource "aws_ecs_service" "cloud_a_service" {
  name            = "seg-cloud-a-service"
  cluster         = aws_ecs_cluster.cloud_a_cluster.id
  task_definition = aws_ecs_task_definition.cloud_a_task.arn
  desired_count   = 1
  # required to allow tracking of the deployed container's IP 
  # (https://stackoverflow.com/questions/75856201/how-to-retrieve-the-public-ip-address-of-an-aws-ecs-contrainer-using-terraform)
  enable_ecs_managed_tags = true
  wait_for_steady_state   = true

  network_configuration {
    subnets          = [local.workload_subnet_id]
    assign_public_ip = false
    security_groups  = [aws_security_group.allow_all.id]
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }

}
