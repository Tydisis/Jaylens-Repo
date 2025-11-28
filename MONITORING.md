# Monitoring Setup and Validation

## Components

- **Spring Boot Actuator**: Health checks and metrics endpoints
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards

## Endpoints

### Application Endpoints
- **Health**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/actuator/health
- **Metrics**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/actuator/metrics
- **Prometheus**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/actuator/prometheus

### Monitoring Dashboard
- **Grafana**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana
  - Username: `admin`
  - Password: `admin123`

## Validation Steps

### 1. Verify Actuator Endpoints
```bash
# Health check
curl http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/actuator/health

# Prometheus metrics
curl http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/actuator/prometheus | head -20
```

### 2. Check Prometheus Targets
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Visit http://localhost:9090/targets
# Look for "spring-boot-app" target - should be UP
```

### 3. Verify Grafana Dashboards

1. Access Grafana: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana
2. Login with admin/admin123
3. Navigate to Dashboards
4. Pre-installed dashboards:
   - **Kubernetes / Compute Resources / Cluster**
   - **Kubernetes / Compute Resources / Namespace (Pods)**
   - **Node Exporter / Nodes**

### 4. Create Custom Spring Boot Dashboard

1. In Grafana, click "+" → "Dashboard"
2. Add Panel
3. Query: `rate(http_server_requests_seconds_count[5m])`
4. Title: "HTTP Request Rate"
5. Save dashboard

## Metrics Available

### Application Metrics (from Actuator)
- `http_server_requests_seconds_count` - HTTP request count
- `http_server_requests_seconds_sum` - HTTP request duration
- `jvm_memory_used_bytes` - JVM memory usage
- `jvm_threads_live_threads` - Active threads
- `process_cpu_usage` - CPU usage

### Kubernetes Metrics (from kube-state-metrics)
- `kube_pod_status_phase` - Pod status
- `kube_deployment_status_replicas` - Deployment replicas
- `container_cpu_usage_seconds_total` - Container CPU
- `container_memory_usage_bytes` - Container memory

## Troubleshooting

### ServiceMonitor not scraping
```bash
# Check ServiceMonitor
kubectl get servicemonitor spring-boot-app -o yaml

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

### Grafana not accessible
```bash
# Check Grafana pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check ingress
kubectl get ingress grafana -n monitoring
```

### Metrics not showing
```bash
# Test actuator endpoint directly
kubectl port-forward deployment/spring-boot-app 8080:8080
curl http://localhost:8080/actuator/prometheus
```

## Interview Talking Points

- **Observability**: Full-stack monitoring from application to infrastructure
- **Proactive Monitoring**: Real-time metrics and alerting capabilities
- **Production-Ready**: Health checks, metrics, and dashboards
- **Cloud-Native**: Kubernetes-native monitoring with Prometheus Operator
- **Best Practices**: Structured metrics, standardized endpoints, automated discovery
