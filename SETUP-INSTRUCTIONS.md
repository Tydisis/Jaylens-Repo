# Complete Infrastructure Setup Guide

## Architecture Overview

This project demonstrates a production-grade CI/CD pipeline with:
- **EKS Cluster**: Kubernetes cluster for application hosting
- **GitHub Actions Runner Controller (ARC)**: Self-hosted runners on Kubernetes
- **Docker-in-Docker**: Containerized builds within Kubernetes
- **AWS Load Balancer Controller**: Automatic ALB provisioning via Ingress
- **Prometheus + Grafana**: Full observability stack
- **Spring Boot Application**: With Actuator metrics and health checks

## Infrastructure Components

### 1. EKS Cluster Setup

**Cluster**: `cicd-cluster` (us-east-1)

**Node Groups**:
- `arc-nodes`: t3.medium (2 nodes) - GitHub Actions runners
- `standard-workers`: Application workloads

**Created with eksctl**:
```bash
eksctl create cluster --name cicd-cluster --region us-east-1
eksctl create nodegroup --cluster cicd-cluster --name arc-nodes --node-type t3.medium --nodes 2
```

### 2. Actions Runner Controller (ARC)

**Installation**:
```bash
# Install controller
helm install arc-controller \
  --namespace arc-systems \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# Install runner scale set
helm install arc-runner-set \
  --namespace arc-runners \
  --create-namespace \
  --set githubConfigUrl="https://github.com/Tydisis/Jaylens-Repo" \
  --set githubConfigSecret.github_token="YOUR_PAT" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

**Runner Configuration**: Docker-in-Docker sidecar for containerized builds

### 3. AWS Load Balancer Controller

**Prerequisites**:
```bash
# Enable OIDC provider
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=cicd-cluster --approve

# Create IAM policy and service account
eksctl create iamserviceaccount \
  --cluster=cicd-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

**Installation**:
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cicd-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4. Monitoring Stack (Prometheus + Grafana)

**Installation**:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

**Access**: http://ALB_URL/grafana/ (admin/admin123)

### 5. Application Deployment

**Kubernetes Resources**:
- `k8s/deployment.yaml` - Application deployment (2 replicas)
- `k8s/ingress.yaml` - ALB ingress for app and Grafana
- `k8s/servicemonitor.yaml` - Prometheus metrics scraping

**Deploy**:
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/servicemonitor.yaml
```

## GitHub Secrets Required

Add to: https://github.com/Tydisis/Jaylens-Repo/settings/secrets/actions

- `DOCKER_USERNAME` - Docker Hub username
- `DOCKER_PASSWORD` - Docker Hub password/token

## CI/CD Workflow

**Trigger**: Push to `JavaApp/**` directory

**Steps**:
1. Maven build and test validation
2. Multi-stage Docker build
3. Push to Docker Hub (latest + commit SHA tags)
4. Update Kubernetes deployment with new image
5. Rolling update with zero downtime

## Resource Tagging

All resources tagged with `auto-delete: never`:
- Node groups: `arc-nodes`, `standard-workers`
- Auto Scaling Groups
- Application Load Balancer

## Validation

**Application**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com

**Monitoring**: http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana/

**Health Check**: `/actuator/health`

**Metrics**: `/actuator/prometheus`

See [MONITORING.md](MONITORING.md) for detailed monitoring validation.

## Troubleshooting

**Check runner pods**:
```bash
kubectl get pods -n arc-runners
```

**Check application pods**:
```bash
kubectl get pods -l app=spring-boot-app
kubectl logs -l app=spring-boot-app
```

**Check ingress**:
```bash
kubectl get ingress -A
kubectl describe ingress spring-boot-app
```

**Check workflow runs**: https://github.com/Tydisis/Jaylens-Repo/actions
git add .
git commit -m "Add Docker CI/CD pipeline"
git push
```

### 4. Watch the Build

- Go to: https://github.com/Tydisis/Jaylens-Repo/actions
- You'll see the workflow running on your ARC runners
- Check runner pods: `kubectl get pods -n arc-runners -w`

## How It Works

1. You push code to GitHub
2. GitHub Actions triggers on the ARC runner
3. Runner builds Docker image
4. Image is pushed to Docker Hub with tags:
   - `latest` (always current)
   - `<commit-sha>` (specific version)

## Pull and Run Your Image

```bash
docker pull <your-dockerhub-username>/spring-boot-app:latest
docker run -p 8080:8080 <your-dockerhub-username>/spring-boot-app:latest
```

## Alternative: Push to Amazon ECR

If you want to use ECR instead of Docker Hub, replace the login step with:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/ROLE
    aws-region: us-east-1

- name: Login to Amazon ECR
  uses: aws-actions/amazon-ecr-login@v2

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: ./JavaApp
    push: true
    tags: ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/spring-boot-app:latest
```
