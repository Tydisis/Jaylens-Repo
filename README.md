# Jaylens-Repo
A repo for pet projects

## Spring Boot Application with CI/CD

This repository contains a Spring Boot application with automated Docker image builds and Kubernetes deployment.

### Live Demo

**Application**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com

**Monitoring Dashboard**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana/
- Username: `admin`
- Password: `admin123`

**Metrics Endpoints**:
- Health: `/actuator/health`
- Prometheus: `/actuator/prometheus`
- Metrics: `/actuator/metrics`

### Features

- **Automated CI/CD Pipeline**: GitHub Actions with self-hosted runners on EKS
- **Docker-in-Docker**: Containerized builds in Kubernetes
- **Zero-Downtime Deployments**: Rolling updates with health checks
- **Monitoring & Observability**: Prometheus + Grafana stack
- **Production Metrics**: Spring Boot Actuator with Prometheus integration
- **Infrastructure as Code**: Kubernetes manifests for reproducible deployments
- **Immutable Deployments**: Image tagging with commit SHA for traceability
- **Auto-Scaling Infrastructure**: ARC runners scale from 0 based on demand

### Docker Image

Pull and run the latest image:
```bash
docker pull jaystew/spring-boot-app:latest
docker run -p 8080:8080 jaystew/spring-boot-app:latest
```

Access the application:
- **Live on AWS**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com
- **Local**: http://localhost:8080

### Local Development

Build and run locally:
```bash
cd JavaApp
./mvnw spring-boot:run
```

Build Docker image locally:
```bash
cd JavaApp
docker build -t spring-boot-app .
docker run -p 8080:8080 spring-boot-app
```

### CI/CD Pipeline

**Architecture:**
- **Self-Hosted Runners**: Actions Runner Controller (ARC) deployed on Amazon EKS cluster `cicd-cluster`
- **Runner Scale Set**: `arc-runner-set` automatically scales from 0 based on workflow demand
- **Kubernetes Namespaces**: Controller in `arc-systems`, runners spawn in `arc-runners`

**Workflow Process:**
1. Developer pushes code changes to `JavaApp/` directory
2. GitHub webhook triggers workflow on self-hosted ARC runner
3. **Build Validation**: Maven compiles and runs tests (`./mvnw clean verify`)
4. **Quality Gate**: Build fails if tests don't pass
5. Runner pod spawns on EKS cluster (t3.medium nodes)
6. Multi-stage Docker build:
   - Stage 1: Maven build with dependency caching
   - Stage 2: Minimal JRE runtime image
7. Docker image pushed to Docker Hub with tags:
   - `latest` - always points to most recent build
   - `<commit-sha>` - immutable version for rollbacks
8. **Automated Deployment**: Kubernetes deployment updated with new image SHA
9. **Rolling Update**: Zero-downtime deployment with health checks
10. Runner pod terminates after job completion

**CI/CD Best Practices Implemented:**
- ✅ Automated testing before deployment
- ✅ Immutable image tags (commit SHA)
- ✅ Zero-downtime rolling updates
- ✅ Build artifact versioning
- ✅ Automated deployment pipeline
- ✅ Infrastructure as Code (Kubernetes manifests)
- ✅ Monitoring and observability (Prometheus/Grafana)

**Benefits:**
- **Cost Efficient**: Runners scale to zero when idle
- **Fast Builds**: Dedicated compute resources, no queue times
- **Build Cache**: GitHub Actions cache persists between builds
- **Secure**: Runners isolated in private VPC subnets

View workflow runs: [Actions Tab](../../actions)  
Monitor runners: `kubectl get pods -n arc-runners -w`

### Setup & Documentation

- **Setup Guide**: [SETUP-INSTRUCTIONS.md](SETUP-INSTRUCTIONS.md) - Complete infrastructure setup
- **Monitoring Guide**: [MONITORING.md](MONITORING.md) - Observability stack validation and usage

## Kubernetes Deployment

The application is deployed to EKS and exposed via AWS Application Load Balancer.

### Live Application

**URL**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com

**Grafana Dashboard**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana
- Username: `admin`
- Password: `admin123`

### Infrastructure

- **EKS Cluster**: cicd-cluster (us-east-1)
- **Deployment**: 2 replicas of `jaystew/spring-boot-app:latest`
- **Service**: NodePort (port 80 → 8080)
- **Ingress**: AWS ALB Controller managing Application Load Balancer
- **Monitoring**: Prometheus + Grafana stack
  - Prometheus for metrics collection
  - Grafana for visualization and dashboards
  - ServiceMonitor for Spring Boot metrics
- **Node Groups**:
  - `arc-nodes` - t3.medium (2 nodes) for GitHub Actions runners
  - `standard-workers` - for application workloads

### Kubernetes Resources

```bash
# View deployment
kubectl get deployment spring-boot-app

# View pods
kubectl get pods -l app=spring-boot-app

# View service
kubectl get svc spring-boot-app

# View ingress and ALB
kubectl get ingress spring-boot-app
```

All resources tagged with `auto-delete: never` for persistence.
