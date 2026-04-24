terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    rabbitmq = {
      source  = "cyrilgdn/rabbitmq"
      version = "~> 1.8"
    }
  }
}

provider "kubernetes" {
  config_path = "C:/Users/USER/.kube/admin.config"
}

provider "rabbitmq" {
  endpoint = var.rabbitmq_endpoint
  username = var.rabbitmq_username
  password = var.rabbitmq_password
}