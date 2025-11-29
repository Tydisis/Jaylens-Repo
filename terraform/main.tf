terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "spring-boot-cicd"
      ManagedBy   = "terraform"
      Owner       = "jaylen"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "networking" {
  source = "./modules/networking"
  
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source = "./modules/eks"
  
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.private_subnet_ids
  
  node_groups = var.node_groups
}

module "monitoring" {
  source = "./modules/monitoring"
  
  cluster_name = module.eks.cluster_name
  
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password
  
  depends_on = [module.eks]
}

module "github_runners" {
  source = "./modules/github-runners"
  
  cluster_name      = module.eks.cluster_name
  github_token      = var.github_token
  github_repository = var.github_repository
  
  depends_on = [module.eks]
}
