# Jaylens-Repo
A repo for pet projects

## Spring Boot Application with CI/CD

This repository contains a Spring Boot application with automated Docker image builds.

### Features

- **Automated Docker Builds**: Every push to `JavaApp/` triggers an automatic Docker image build
- **Self-Hosted Runners**: Uses Actions Runner Controller (ARC) on EKS for fast, scalable builds
- **Multi-Stage Builds**: Optimized Docker images using Eclipse Temurin JDK/JRE
- **Automatic Versioning**: Images tagged with `latest` and commit SHA

### Docker Image

Pull and run the latest image:
```bash
docker pull jaystew/spring-boot-app:latest
docker run -p 8080:8080 jaystew/spring-boot-app:latest
```

Access the application:
- **Live on AWS**: http://k8s-default-springbo-980d1a91d7-1024312859.us-east-1.elb.amazonaws.com
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
3. Runner pod spawns on EKS cluster (t3.medium nodes)
4. Multi-stage Docker build:
   - Stage 1: Maven build with dependency caching
   - Stage 2: Minimal JRE runtime image
5. Docker image pushed to Docker Hub with tags:
   - `latest` - always points to most recent build
   - `<commit-sha>` - immutable version for rollbacks
6. Runner pod terminates after job completion

**Benefits:**
- **Cost Efficient**: Runners scale to zero when idle
- **Fast Builds**: Dedicated compute resources, no queue times
- **Build Cache**: GitHub Actions cache persists between builds
- **Secure**: Runners isolated in private VPC subnets

View workflow runs: [Actions Tab](../../actions)  
Monitor runners: `kubectl get pods -n arc-runners -w`

### Setup

See [SETUP-INSTRUCTIONS.md](SETUP-INSTRUCTIONS.md) for complete setup guide.

## Kubernetes Deployment

The application is deployed to EKS and exposed via AWS Application Load Balancer.

### Live Application

**URL**: http://k8s-default-springbo-980d1a91d7-1024312859.us-east-1.elb.amazonaws.com

### Infrastructure

- **EKS Cluster**: cicd-cluster (us-east-1)
- **Deployment**: 2 replicas of `jaystew/spring-boot-app:latest`
- **Service**: NodePort (port 80 → 8080)
- **Ingress**: AWS ALB Controller managing Application Load Balancer
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
