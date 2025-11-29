# Complete Infrastructure Setup Guide

This guide walks you through recreating the entire CI/CD infrastructure from scratch using Terraform.

## What This Creates

### AWS Infrastructure
- **VPC**: 192.168.0.0/16 with 3 public and 3 private subnets across 3 availability zones
- **NAT Gateways**: 3 NAT gateways (one per AZ) for private subnet internet access
- **Internet Gateway**: For public subnet internet access
- **Route Tables**: Configured for public and private subnet routing

### EKS Cluster
- **Kubernetes Cluster**: Version 1.31 with managed control plane
- **Node Group**: 3 t3.medium EC2 instances (auto-scaling 2-5)
- **OIDC Provider**: For IAM Roles for Service Accounts (IRSA)
- **IAM Roles**: Cluster role, node role, and ALB controller role

### Kubernetes Add-ons
- **AWS Load Balancer Controller**: Manages ALB/NLB for ingress resources
- **Prometheus**: Metrics collection and storage
- **Grafana**: Monitoring dashboards and visualization
- **GitHub Actions Runner Controller**: Self-hosted runners in Kubernetes

### RBAC Configuration
- **Service Account**: `github-actions-deployer` for CI/CD workflows
- **ClusterRole**: Permissions to manage deployments and pods
- **ClusterRoleBinding**: Links service account to cluster role

## Prerequisites

### 1. Install Required Tools

**Terraform**
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**AWS CLI**
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**kubectl**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Helm**
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json
```

Verify access:
```bash
aws sts get-caller-identity
```

### 3. Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes:
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
4. Copy the token (starts with `ghp_`)

## Step-by-Step Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO/terraform
```

### Step 2: Configure Variables

Copy the example file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region = "us-east-1"
cluster_name = "cicd-cluster"

grafana_admin_user = "admin"
grafana_admin_password = "your-secure-password"

github_token = "ghp_YOUR_ACTUAL_TOKEN"
github_repository = "https://github.com/YOUR_USERNAME/YOUR_REPO"
```

**Security Note**: Never commit `terraform.tfvars` to git (it's in .gitignore)

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads required providers:
- AWS provider
- Kubernetes provider
- Helm provider

### Step 4: Review Plan

```bash
terraform plan
```

Review the resources that will be created:
- 1 VPC
- 6 Subnets (3 public, 3 private)
- 3 NAT Gateways
- 1 Internet Gateway
- 1 EKS Cluster
- 1 Node Group
- 3 Helm releases
- Multiple IAM roles and policies

### Step 5: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Duration**: 15-20 minutes
- VPC/Networking: 2-3 minutes
- EKS Cluster: 10-12 minutes
- Node Group: 3-5 minutes
- Helm Charts: 2-3 minutes

### Step 6: Configure kubectl

```bash
aws eks update-kubeconfig --name cicd-cluster --region us-east-1
```

Verify connection:
```bash
kubectl get nodes
```

Expected output:
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-192-168-x-x.ec2.internal  Ready    <none>   5m    v1.31.x
ip-192-168-x-x.ec2.internal  Ready    <none>   5m    v1.31.x
ip-192-168-x-x.ec2.internal  Ready    <none>   5m    v1.31.x
```

### Step 7: Verify Deployments

**Check all pods:**
```bash
kubectl get pods -A
```

**Check ALB Controller:**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Check Monitoring Stack:**
```bash
kubectl get pods -n monitoring
```

**Check GitHub Runners:**
```bash
kubectl get pods -n arc-systems
kubectl get pods -n arc-runners
```

### Step 8: Get Load Balancer URL

```bash
kubectl get ingress -n monitoring
```

Wait for ALB to provision (2-3 minutes). Copy the ADDRESS column.

Access Grafana:
```
http://YOUR-ALB-DNS/grafana/
```

Login with credentials from `terraform.tfvars`.

## Deploy Your Application

### Option 1: Using kubectl

```bash
cd ../k8s
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

### Option 2: Using CI/CD

Push code to trigger GitHub Actions:
```bash
git add .
git commit -m "Deploy application"
git push
```

Runners will automatically build and deploy.

## Verify Everything Works

### 1. Check Application Pods
```bash
kubectl get pods -n default
```

### 2. Check Ingress
```bash
kubectl get ingress -A
```

### 3. Access Application
```
http://YOUR-ALB-DNS/
```

### 4. Check Monitoring
```
http://YOUR-ALB-DNS/grafana/
```

### 5. View Metrics
In Grafana, go to Explore and query:
```promql
rate(http_server_requests_seconds_count[5m])
```

## Cost Management

### Monthly Costs (us-east-1)
- EKS Control Plane: $73
- 3x t3.medium nodes: $90 (24/7)
- 3x NAT Gateways: $100
- Application Load Balancer: $20
- Data transfer: ~$10
- **Total: ~$293/month**

### Cost Optimization Options

**1. Single NAT Gateway** (Save $67/month)
Edit `terraform/modules/networking/main.tf`:
```hcl
resource "aws_nat_gateway" "main" {
  count = 1  # Change from 3 to 1
  # ...
}
```

**2. Smaller Instances** (Save $45/month)
Edit `terraform.tfvars`:
```hcl
node_groups = {
  general = {
    instance_types = ["t3.small"]  # Change from t3.medium
  }
}
```

**3. Fargate for Runners** (Variable cost)
Only pay when workflows run instead of 24/7 nodes.

## Troubleshooting

### Terraform Apply Fails

**Error: VPC limit reached**
```bash
aws ec2 describe-vpcs --region us-east-1
# Delete unused VPCs or request limit increase
```

**Error: EKS cluster creation timeout**
- Check AWS service health dashboard
- Verify IAM permissions
- Check subnet configuration

### kubectl Connection Issues

**Error: Unable to connect to server**
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --name cicd-cluster --region us-east-1

# Verify AWS credentials
aws sts get-caller-identity
```

### ALB Not Creating

**Ingress shows no ADDRESS**
```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify IAM role
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### Pods Not Starting

**ImagePullBackOff error**
```bash
# Check if nodes can pull images
kubectl describe pod POD_NAME -n NAMESPACE

# Verify node IAM role has ECR permissions
```

### GitHub Runners Not Connecting

**No runners showing in GitHub**
```bash
# Check runner controller
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-runner-scale-set-controller

# Verify GitHub token
kubectl get secret -n arc-runners
```

## Cleanup

### Delete Application Resources First
```bash
kubectl delete ingress --all -A
kubectl delete svc --all -A
```

Wait 2-3 minutes for load balancers to delete.

### Destroy Infrastructure
```bash
terraform destroy
```

Type `yes` when prompted.

**If destroy hangs:**
1. Check AWS Console for remaining load balancers
2. Manually delete ALB/NLB
3. Re-run `terraform destroy`

## Next Steps

1. **Set up DNS**: Point custom domain to ALB
2. **Enable HTTPS**: Add ACM certificate to ALB
3. **Configure Monitoring**: Import Grafana dashboards
4. **Set up Alerts**: Configure Prometheus alerting rules
5. **Implement Autoscaling**: Add HPA for application pods
6. **Add Logging**: Deploy Fluent Bit for log aggregation

## Security Best Practices

- Store secrets in AWS Secrets Manager
- Enable VPC Flow Logs
- Implement Pod Security Standards
- Use private ECR for container images
- Enable EKS audit logging
- Rotate IAM credentials regularly
- Use least privilege IAM policies

## Support

For issues or questions:
- Check Terraform documentation: https://registry.terraform.io/providers/hashicorp/aws
- EKS Best Practices: https://aws.github.io/aws-eks-best-practices/
- Kubernetes documentation: https://kubernetes.io/docs/
