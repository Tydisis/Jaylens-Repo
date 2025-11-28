# Jaylens-Repo
Cloud-Native Spring Boot Application with Full CI/CD Pipeline

## 🚀 Live Demo

**Application**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com

**Monitoring Dashboard**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana/
- Username: `admin`
- Password: `admin123`

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Spring Boot Application](#spring-boot-application)
- [Kubernetes Infrastructure](#kubernetes-infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring & Observability](#monitoring--observability)
- [Documentation](#documentation)

## Overview

This project demonstrates a production-grade cloud-native application with:
- **Spring Boot** application with Actuator metrics
- **Kubernetes** deployment on Amazon EKS
- **GitHub Actions** CI/CD with self-hosted runners
- **Prometheus + Grafana** monitoring stack
- **AWS Load Balancer** for ingress
- **Zero-downtime** rolling deployments

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│  ┌──────────────┐         ┌─────────────────────────────┐  │
│  │  JavaApp/    │────────▶│  GitHub Actions Workflow    │  │
│  │  - src/      │         │  - Build & Test             │  │
│  │  - pom.xml   │         │  - Docker Build             │  │
│  │  - Dockerfile│         │  - Push to Docker Hub       │  │
│  └──────────────┘         │  - Deploy to Kubernetes     │  │
│                            └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────┐
│              Amazon EKS Cluster (cicd-cluster)               │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  arc-runners namespace                                  │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  GitHub Actions Runner Pods (Docker-in-Docker)   │  │ │
│  │  │  - Ephemeral runners                             │  │ │
│  │  │  - Scale from 0 based on workflow demand         │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  default namespace                                      │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │  Spring Boot App Pods (2 replicas)              │  │ │
│  │  │  - Health checks & readiness probes              │  │ │
│  │  │  - Prometheus metrics exposed                    │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  monitoring namespace                                   │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │ │
│  │  │  Prometheus  │  │   Grafana    │  │ Alertmanager│  │ │
│  │  └──────────────┘  └──────────────┘  └─────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────┐
│          AWS Application Load Balancer (ALB)                 │
│  - Path-based routing: / → App, /grafana/ → Grafana         │
│  - Health checks on /actuator/health                         │
└─────────────────────────────────────────────────────────────┘
```

## Spring Boot Application

### Technology Stack
- **Framework**: Spring Boot 4.0.0
- **Java Version**: 25 (Eclipse Temurin)
- **Build Tool**: Maven with wrapper
- **Observability**: Spring Boot Actuator + Micrometer

### Key Features
- **Health Checks**: `/actuator/health` - Kubernetes liveness/readiness probes
- **Metrics**: `/actuator/prometheus` - Prometheus-format metrics
- **Info Endpoint**: `/actuator/info` - Application metadata
- **Static Content**: Professional portfolio page with monitoring dashboard link

### Application Structure
```
JavaApp/
├── src/
│   ├── main/
│   │   ├── java/com/jaystewwtest/
│   │   │   ├── StoreApplication.java      # Main application class
│   │   │   ├── OrderService.java          # Business logic
│   │   │   └── StripePaymentService.java  # Payment service
│   │   └── resources/
│   │       ├── application.properties      # Actuator configuration
│   │       └── static/
│   │           └── index.html              # Portfolio page
│   └── test/                               # Unit tests
├── pom.xml                                 # Maven dependencies
├── Dockerfile                              # Multi-stage build
└── .mvn/                                   # Maven wrapper
```

### Dependencies
```xml
<dependencies>
    <!-- Web Framework -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <!-- Observability -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
    <!-- Metrics -->
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
</dependencies>
```

### Local Development
```bash
# Run application
cd JavaApp
./mvnw spring-boot:run

# Run tests
./mvnw test

# Build JAR
./mvnw clean package

# Access locally
http://localhost:8080
```

## Kubernetes Infrastructure

### EKS Cluster Configuration
- **Cluster Name**: cicd-cluster
- **Region**: us-east-1
- **Kubernetes Version**: 1.28+
- **Node Groups**:
  - `arc-nodes`: t3.medium (2 nodes) - GitHub Actions runners
  - `standard-workers`: Application workloads

### Kubernetes Resources

#### Deployment (`k8s/deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-boot-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-boot-app
  template:
    spec:
      containers:
      - name: spring-boot-app
        image: jaystew/spring-boot-app:latest
        ports:
        - containerPort: 8080
```

**Features**:
- 2 replicas for high availability
- Rolling update strategy (zero downtime)
- Resource requests/limits (best practice)
- Health checks via Actuator endpoints

#### Service (`k8s/deployment.yaml`)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-boot-app
spec:
  type: NodePort
  selector:
    app: spring-boot-app
  ports:
  - port: 80
    targetPort: 8080
```

#### Ingress (`k8s/ingress.yaml`)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: spring-boot-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: spring-boot-app
            port:
              number: 80
```

**Features**:
- AWS Load Balancer Controller manages ALB
- Automatic ALB provisioning
- Path-based routing for app and Grafana
- Health checks integrated

#### ServiceMonitor (`k8s/servicemonitor.yaml`)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: spring-boot-app
spec:
  selector:
    matchLabels:
      app: spring-boot-app
  endpoints:
  - port: metrics
    path: /actuator/prometheus
    interval: 30s
```

**Purpose**: Configures Prometheus to scrape application metrics every 30 seconds

### Deployed Components
```bash
# View all resources
kubectl get all -n default
kubectl get ingress -n default
kubectl get servicemonitor -n default

# Check application logs
kubectl logs -l app=spring-boot-app -f

# Check pod health
kubectl describe pod -l app=spring-boot-app
```

## CI/CD Pipeline

### GitHub Actions Workflow

**Trigger**: Push to `JavaApp/**` directory

**Workflow File**: `.github/workflows/build-and-push.yml`

### Pipeline Stages

#### 1. Build & Test
```yaml
- name: Set up JDK 25
  uses: actions/setup-java@v4
  with:
    java-version: '25'
    distribution: 'temurin'
    cache: 'maven'  # Caches Maven dependencies

- name: Build and test with Maven
  run: ./mvnw clean verify
```

**Features**:
- Maven dependency caching (saves 1-2 minutes)
- Runs unit tests before building Docker image
- Fails fast if tests don't pass

#### 2. Docker Build & Push
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: ./JavaApp
    push: true
    tags: |
      jaystew/spring-boot-app:latest
      jaystew/spring-boot-app:${{ github.sha }}
    cache-from: type=registry,ref=jaystew/spring-boot-app:buildcache
    cache-to: type=registry,ref=jaystew/spring-boot-app:buildcache,mode=max
```

**Features**:
- Multi-stage Dockerfile (build + runtime)
- Docker layer caching (saves 30-60 seconds)
- Immutable tags with commit SHA
- Latest tag for convenience

#### 3. Kubernetes Deployment
```yaml
- name: Install AWS CLI and kubectl
  run: |
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/

- name: Configure kubectl for EKS
  run: aws eks update-kubeconfig --name cicd-cluster --region us-east-1

- name: Update Kubernetes deployment
  run: |
    kubectl set image deployment/spring-boot-app \
      spring-boot-app=jaystew/spring-boot-app:${{ github.sha }} -n default
    kubectl rollout status deployment/spring-boot-app -n default --timeout=120s
```

**Features**:
- Automated deployment with commit SHA
- Rolling update (zero downtime)
- Waits for rollout completion
- Fails if deployment doesn't succeed

### Self-Hosted Runners (ARC)

**Architecture**:
- **Controller**: Manages runner lifecycle in `arc-systems` namespace
- **Listener**: Receives GitHub webhook events
- **Runners**: Ephemeral pods in `arc-runners` namespace with Docker-in-Docker

**Benefits**:
- **Cost Efficient**: Scales to zero when idle
- **Fast Builds**: Dedicated compute, no queue times
- **Secure**: Runs in private VPC subnets
- **Flexible**: Full control over runner environment

**Configuration**:
```bash
# Check runner status
kubectl get pods -n arc-runners
kubectl get pods -n arc-systems

# View runner logs
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner
```

### CI/CD Best Practices Implemented

✅ **Automated Testing** - Maven tests run before deployment  
✅ **Immutable Artifacts** - Docker images tagged with commit SHA  
✅ **Zero-Downtime Deployments** - Kubernetes rolling updates  
✅ **Build Caching** - Maven and Docker layer caching  
✅ **Infrastructure as Code** - All configs in Git  
✅ **Monitoring Integration** - Prometheus metrics from build to production  
✅ **RBAC Security** - ServiceAccount with minimal permissions  

## Monitoring & Observability

### Stack Components

#### Prometheus
- **Purpose**: Metrics collection and storage
- **Scrape Interval**: 30 seconds
- **Targets**: Application pods, Kubernetes components, node exporters
- **Retention**: 15 days (default)

#### Grafana
- **Purpose**: Visualization and dashboards
- **Access**: http://ALB_URL/grafana/
- **Credentials**: admin / admin123
- **Pre-installed Dashboards**:
  - Kubernetes Cluster Overview
  - Node Exporter Metrics
  - Pod Resource Usage

#### Spring Boot Actuator
- **Health**: `/actuator/health` - Application health status
- **Metrics**: `/actuator/prometheus` - Prometheus-format metrics
- **Info**: `/actuator/info` - Application metadata

### Available Metrics

**Application Metrics**:
- `http_server_requests_seconds_count` - HTTP request count
- `http_server_requests_seconds_sum` - HTTP request duration
- `jvm_memory_used_bytes` - JVM memory usage
- `jvm_threads_live_threads` - Active threads
- `process_cpu_usage` - CPU usage

**Kubernetes Metrics**:
- `kube_pod_status_phase` - Pod status
- `kube_deployment_status_replicas` - Deployment replicas
- `container_cpu_usage_seconds_total` - Container CPU
- `container_memory_usage_bytes` - Container memory

### Validation

See [MONITORING.md](MONITORING.md) for detailed monitoring setup and validation steps.

## Documentation

- **[SETUP-INSTRUCTIONS.md](SETUP-INSTRUCTIONS.md)** - Complete infrastructure setup guide
- **[MONITORING.md](MONITORING.md)** - Monitoring stack validation and usage
- **[.github/workflows/build-and-push.yml](.github/workflows/build-and-push.yml)** - CI/CD pipeline configuration

## Quick Commands

```bash
# Application
kubectl get pods -l app=spring-boot-app
kubectl logs -l app=spring-boot-app -f
kubectl describe deployment spring-boot-app

# Monitoring
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# CI/CD
kubectl get pods -n arc-runners
kubectl get pods -n arc-systems
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner

# Ingress
kubectl get ingress -A
kubectl describe ingress spring-boot-app
```

## Technologies Used

**Application**: Spring Boot, Java 25, Maven, Actuator, Micrometer  
**Containerization**: Docker, Multi-stage builds  
**Orchestration**: Kubernetes, Amazon EKS  
**CI/CD**: GitHub Actions, Actions Runner Controller (ARC)  
**Monitoring**: Prometheus, Grafana, ServiceMonitor  
**Infrastructure**: AWS (EKS, ALB, EC2), Helm  
**IaC**: Kubernetes manifests, Helm charts  

---

**Author**: Jaylen Steward  
**Contact**: jaylen770@gmail.com  
**LinkedIn**: [linkedin.com/in/jaylen-steward](https://www.linkedin.com/in/jaylen-steward)
