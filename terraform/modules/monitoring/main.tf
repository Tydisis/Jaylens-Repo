resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.0"
  
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "79.9.0"
  
  create_namespace = true
  
  values = [
    yamlencode({
      grafana = {
        adminUser     = var.grafana_admin_user
        adminPassword = var.grafana_admin_password
        
        "grafana.ini" = {
          server = {
            root_url              = "http://localhost/grafana/"
            serve_from_sub_path   = true
          }
        }
      }
      
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
        }
      }
    })
  ]
}

resource "kubernetes_manifest" "grafana_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "grafana"
      namespace = "monitoring"
      annotations = {
        "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
        "alb.ingress.kubernetes.io/target-type" = "ip"
        "alb.ingress.kubernetes.io/group.name"  = "main-alb"
        "alb.ingress.kubernetes.io/group.order" = "1"
        "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
      }
    }
    spec = {
      ingressClassName = "alb"
      rules = [{
        http = {
          paths = [{
            path     = "/grafana"
            pathType = "Prefix"
            backend = {
              service = {
                name = "prometheus-grafana"
                port = {
                  number = 80
                }
              }
            }
          }]
        }
      }]
    }
  }
  
  depends_on = [helm_release.prometheus, helm_release.alb_controller]
}
