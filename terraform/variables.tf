// F5XC VARIABLES
variable "api_cert" {
  type    = string
  default = "e-xpertsolutions.console.ves.volterra.io.api-creds.p12"
}

variable "api_url" {
  type    = string
  default = "https://e-xpertsolutions.console.ves.volterra.io/api"
}

variable "namespace" {
  type    = string
  default = "seg360-2024-demo"
}

variable "tenant" {
  type    = string
  default = "e-xpertsolutions-moyijavn"
}

variable "app_subdomain" {
  type    = string
  default = "tde-seg"
}

variable "app_domain" {
  type    = string
  default = "e-xpertsolutions.net"
}

variable "cloud_b_subdomain" {
  type    = string
  default = "friends"
}

variable "cloud_c_subdomain" {
  type    = string
  default = "transfer"
}

variable "on_prem_site" {
  type    = string
  default = "tde-seg-ce-vmware-gve"
}

// AWS VARIABLES
variable "aws_ssh_key" {
  type      = string
  sensitive = true
}

variable "aws_f5xc_access_key" {
  type      = string
  sensitive = true
}

variable "aws_f5xc_secret_key_blindfolded" {
  type      = string
  sensitive = true
}

variable "aws_ecs_access_key" {
  type      = string
  sensitive = true
}

variable "aws_ecs_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "aws_az" {
  type    = string
  default = "eu-central-1a"
}

variable "aws_reverse_proxy_image" {
  type    = string
  default = "public.ecr.aws/t0m8o0y8/tde-seg-reverse-proxy"
}

variable "aws_frontend_image" {
  type    = string
  default = "public.ecr.aws/t0m8o0y8/tde-seg-frontend"
}

variable "aws_backend_image" {
  type    = string
  default = "public.ecr.aws/t0m8o0y8/tde-seg-backend"
}

variable "aws_fastcgi_image" {
  type    = string
  default = "public.ecr.aws/t0m8o0y8/tde-seg-fastcgi"
}
