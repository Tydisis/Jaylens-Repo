# Cloud-Native Spring Boot Application

Production-grade Spring Boot application with automated CI/CD pipeline on Amazon EKS.

## 🚀 Live Demo

**Application**: [http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com](http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com)

**Grafana Dashboard**: [http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana/](http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/grafana/) (continuous/improvement)

## 🏗️ Architecture

```
GitHub → Actions Runner (EKS) → Docker Build → Docker Hub → K8s Deployment → ALB
                                                                    ↓
                                                            Prometheus/Grafana
```

**Key Components**:
- Spring Boot app with Actuator metrics
- Self-hosted GitHub Actions runners on Kubernetes
- Automated CI/CD with zero-downtime deployments
- Prometheus + Grafana monitoring
- AWS Application Load Balancer

## 📚 Documentation

- **[SETUP-GUIDE.md](terraform/SETUP-GUIDE.md)** - Complete infrastructure setup with Terraform (recreate everything from scratch)
- **[APPLICATION.md](docs/APPLICATION.md)** - Spring Boot app details, dependencies, local development
- **[KUBERNETES.md](docs/KUBERNETES.md)** - K8s resources, deployment configuration, commands
- **[CICD.md](docs/CICD.md)** - GitHub Actions workflow, pipeline stages, best practices
- **[VISITOR-COUNTER.md](docs/VISITOR-COUNTER.md)** - Visitor tracking implementation, rate limiting, architecture
- **[MONITORING.md](docs/MONITORING.md)** - Observability stack, metrics, validation
- **[INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md)** - Complete setup guide, EKS cluster, ARC installation

## 🚀 Quick Start

```bash
# Local development
cd JavaApp && ./mvnw spring-boot:run

# Deploy to Kubernetes
kubectl apply -f k8s/

# View application
kubectl get pods -l app=spring-boot-app
```

## 🛠️ Technologies

**Application**: Spring Boot 4.0, Java 17, Maven  
**Container**: Docker, Multi-stage builds  
**Orchestration**: Kubernetes, Amazon EKS  
**CI/CD**: GitHub Actions, ARC  
**Monitoring**: Prometheus, Grafana, Actuator  
**Cloud**: AWS (EKS, ALB, EC2)

## 📊 CI/CD Features

✅ Automated testing before deployment  
✅ Docker layer caching  
✅ Immutable deployments (commit SHA tags)  
✅ Zero-downtime rolling updates  
✅ Self-hosted runners on Kubernetes  
✅ Full observability stack

---

**Author**: Jaylen Steward | [LinkedIn](https://www.linkedin.com/in/jaylen-steward) | jaylen770@gmail.com
