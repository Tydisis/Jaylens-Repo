variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "GitHub repository URL"
  type        = string
}
