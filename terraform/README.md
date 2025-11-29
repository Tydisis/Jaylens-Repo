# Infrastructure as Code - Terraform

This directory contains Terraform configuration to provision the entire CI/CD infrastructure on AWS.

## Architecture

```
terraform/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars          # Variable values (gitignored)
└── modules/
    ├── networking/           # VPC, subnets, NAT gateways
    ├── eks/                  # EKS cluster, node groups, IRSA
    ├── monitoring/           # Prometheus, Grafana (Helm)
    └── github-runners/       # Actions Runner Controller (Helm)
```

## Prerequisites

1. **AWS CLI** configured with credentials
2. **Terraform** >= 1.0
3. **kubectl** for Kubernetes access
4. **helm** for chart management

## Quick Start

### 1. Create terraform.tfvars

```hcl
aws_region = "us-east-1"
cluster_name = "cicd-cluster"

grafana_admin_password = "improvement"
github_token = "ghp_YOUR_TOKEN_HERE"
github_repository = "https://github.com/Tydisis/Jaylens-Repo"
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Plan Infrastructure

```bash
terraform plan
```

### 4. Apply Configuration

```bash
terraform apply
```

This will create:
- VPC with 3 public + 3 private subnets across 3 AZs
- NAT Gateways for private subnet internet access
- EKS cluster (Kubernetes 1.31)
- Node group with 3 t3.medium instances
- OIDC provider for IRSA
- ALB Controller with IAM role
- Prometheus + Grafana monitoring stack
- GitHub Actions Runner Controller

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --name cicd-cluster --region us-east-1
```

### 6. Verify Deployment

```bash
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

## Module Details

### Networking Module
- Creates VPC with configurable CIDR
- 3 public subnets (for ALB, NAT gateways)
- 3 private subnets (for EKS nodes)
- Internet Gateway for public access
- NAT Gateways for private subnet egress
- Route tables with proper associations

### EKS Module
- EKS cluster with specified Kubernetes version
- Managed node groups with auto-scaling
- OIDC provider for service account IAM roles
- ALB Controller IAM role and policy
- Security groups for cluster communication

### Monitoring Module
- Installs kube-prometheus-stack via Helm
- Configures Grafana with custom credentials
- Sets up Prometheus ServiceMonitor
- Creates ingress for Grafana dashboard

### GitHub Runners Module
- Installs Actions Runner Controller
- Configures runner scale set
- Sets up RBAC for deployment permissions
- Connects to GitHub repository

## State Management

**Local State (Current)**
- State stored in `terraform.tfstate`
- Not suitable for team collaboration

**Remote State (Recommended)**
Add to `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "cicd-cluster/terraform.tfstate"
    region = "us-east-1"
    
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Cost Estimation

**Monthly costs (us-east-1) - Cost Optimized:**
- EKS cluster: $73
- 3x t3.small spot nodes: ~$23 (70% savings vs on-demand)
- NAT Gateway (1): ~$33
- ALB: ~$20
- **Total: ~$149/month**

**Previous configuration:**
- 3x t3.medium on-demand: $90
- 3x NAT Gateways: $100
- **Previous total: ~$283/month**
- **Savings: $134/month (47%)**

**Cost optimization:**
- Single NAT Gateway: Save $67/month (risk: single point of failure)
- Spot instances: Save $67/month (risk: potential interruption)
- t3.small vs t3.medium: Save $45/month (2GB vs 4GB RAM per node)

## Destroying Infrastructure

```bash
# Delete Kubernetes resources first
kubectl delete ingress --all -A
kubectl delete svc --all -A

# Wait for ALB/NLB deletion (check AWS Console)

# Destroy Terraform resources
terraform destroy
```

**Important:** Delete load balancers manually if Terraform destroy hangs.

## Troubleshooting

### EKS Cluster Creation Timeout
- Check VPC/subnet configuration
- Verify IAM role permissions
- Check AWS service quotas

### ALB Not Creating
- Verify ALB Controller is running: `kubectl get pods -n kube-system`
- Check ingress annotations
- Review ALB Controller logs

### Helm Release Failures
- Check Helm version compatibility
- Verify chart repository access
- Review pod logs for errors

## Next Steps

1. **Deploy Application**
   ```bash
   kubectl apply -f ../k8s/
   ```

2. **Configure DNS**
   - Get ALB DNS: `kubectl get ingress -A`
   - Create Route53 record or use ALB DNS directly

3. **Set up Monitoring**
   - Access Grafana at ALB URL + `/grafana/`
   - Import dashboards for Spring Boot metrics

4. **Configure CI/CD**
   - GitHub Actions will auto-deploy on push
   - Runners execute within the cluster

## Security Considerations

- Store sensitive variables in AWS Secrets Manager
- Use IAM roles instead of access keys
- Enable VPC Flow Logs for network monitoring
- Implement Pod Security Standards
- Regular security updates for node AMIs

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ALB Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
