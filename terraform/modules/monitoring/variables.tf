variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}
