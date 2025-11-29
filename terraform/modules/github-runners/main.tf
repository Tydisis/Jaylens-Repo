resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"
  }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
  }
}

resource "helm_release" "arc_controller" {
  name       = "arc"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  namespace  = kubernetes_namespace.arc_systems.metadata[0].name
  version    = "0.13.0"
}

resource "kubernetes_service_account" "github_actions_deployer" {
  metadata {
    name      = "github-actions-deployer"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "deployment_manager" {
  metadata {
    name = "deployment-manager"
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "update", "patch", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "github_actions_deployment_manager" {
  metadata {
    name = "github-actions-deployment-manager"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.deployment_manager.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions_deployer.metadata[0].name
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
}

resource "helm_release" "arc_runner_set" {
  name       = "arc-runner-set"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  version    = "0.13.0"
  
  set {
    name  = "githubConfigUrl"
    value = var.github_repository
  }
  
  set_sensitive {
    name  = "githubConfigSecret.github_token"
    value = var.github_token
  }
  
  set {
    name  = "template.spec.serviceAccountName"
    value = kubernetes_service_account.github_actions_deployer.metadata[0].name
  }
  
  set {
    name  = "template.spec.containers[0].name"
    value = "runner"
  }
  
  set {
    name  = "template.spec.containers[0].image"
    value = "ghcr.io/actions/actions-runner:latest"
  }
  
  set {
    name  = "template.spec.containers[0].command[0]"
    value = "/home/runner/run.sh"
  }
  
  set {
    name  = "template.spec.containers[0].env[0].name"
    value = "DOCKER_HOST"
  }
  
  set {
    name  = "template.spec.containers[0].env[0].value"
    value = "tcp://localhost:2375"
  }
  
  set {
    name  = "template.spec.containers[1].name"
    value = "dind"
  }
  
  set {
    name  = "template.spec.containers[1].image"
    value = "docker:dind"
  }
  
  set {
    name  = "template.spec.containers[1].securityContext.privileged"
    value = "true"
  }
  
  depends_on = [
    helm_release.arc_controller,
    kubernetes_cluster_role_binding.github_actions_deployment_manager
  ]
}
