variable "rabbitmq_endpoint" {
  description = "RabbitMQ Management API endpoint "
  type        = string
}

variable "rabbitmq_username" {
  description = "RabbitMQ admin username"
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ admin password"
  type        = string
  sensitive   = true
}

variable "vhost" {
  description = "RabbitMQ vhost"
  type        = string
  default     = "/"
}
