# Cost Optimization Migration Guide

## Changes Made

1. **Single NAT Gateway**: Reduced from 3 to 1 (save $67/month)
2. **Spot Instances**: Changed from on-demand to spot (save ~$67/month)
3. **t3.small**: Changed from t3.medium (save $45/month)

**Total Savings: $134/month (47% reduction)**

## Current vs Optimized

| Component | Current | Optimized | Savings |
|-----------|---------|-----------|---------|
| NAT Gateways | 3x $33 = $100 | 1x $33 = $33 | $67 |
| EC2 Nodes | 3x t3.medium on-demand = $90 | 3x t3.small spot = $23 | $67 |
| Total | $283/month | $149/month | $134 |

## Migration Steps

### Option 1: Recreate with Terraform (Recommended)

**Downtime**: ~20 minutes

```bash
# 1. Backup current state
kubectl get all -A -o yaml > backup.yaml

# 2. Destroy current infrastructure
cd terraform
terraform destroy

# 3. Apply optimized configuration
terraform apply

# 4. Redeploy applications
kubectl apply -f ../k8s/
```

### Option 2: Manual Migration (No Downtime)

#### Step 1: Create New Node Group (Spot + t3.small)

```bash
eksctl create nodegroup \
  --cluster=cicd-cluster \
  --name=general-spot \
  --node-type=t3.small \
  --nodes=3 \
  --nodes-min=2 \
  --nodes-max=5 \
  --spot \
  --region=us-east-1
```

#### Step 2: Drain Old Nodes

```bash
# Get old node names
kubectl get nodes

# Drain each node
kubectl drain ip-192-168-115-133.ec2.internal --ignore-daemonsets --delete-emptydir-data
kubectl drain ip-192-168-186-206.ec2.internal --ignore-daemonsets --delete-emptydir-data
```

#### Step 3: Delete Old Node Group

```bash
eksctl delete nodegroup \
  --cluster=cicd-cluster \
  --name=cicd-cluster-general \
  --region=us-east-1
```

#### Step 4: Remove Extra NAT Gateways

**Via AWS Console:**
1. Go to VPC → NAT Gateways
2. Identify the 2 NAT gateways NOT in use
3. Delete them (keep one in the first AZ)
4. Release the associated Elastic IPs

**Via AWS CLI:**
```bash
# List NAT gateways
aws ec2 describe-nat-gateways --region us-east-1

# Delete NAT gateway (replace with actual ID)
aws ec2 delete-nat-gateway --nat-gateway-id nat-xxxxx --region us-east-1

# Wait for deletion, then release EIP
aws ec2 release-address --allocation-id eipalloc-xxxxx --region us-east-1
```

#### Step 5: Update Route Tables

All private subnet route tables should point to the single NAT gateway:

```bash
# Get route table IDs
aws ec2 describe-route-tables --region us-east-1 \
  --filters "Name=tag:Name,Values=cicd-cluster-private-rt-*"

# Update each route table (replace IDs)
aws ec2 replace-route \
  --route-table-id rtb-xxxxx \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-xxxxx \
  --region us-east-1
```

## Spot Instance Considerations

### Interruption Handling

**Probability**: ~5% chance of interruption per instance per month

**Mitigation**:
- 3 nodes across 3 AZs (redundancy)
- Min 2 nodes (always have capacity)
- 2-minute warning before termination
- Kubernetes automatically reschedules pods

**Monitor interruptions:**
```bash
kubectl get events -A | grep -i spot
```

### Best Practices

1. **Multiple instance types** (fallback options):
```hcl
instance_types = ["t3.small", "t3a.small", "t2.small"]
```

2. **Node affinity** for critical workloads:
```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: eks.amazonaws.com/capacityType
          operator: In
          values:
          - ON_DEMAND
```

3. **Pod Disruption Budgets**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spring-boot-app-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: spring-boot-app
```

## Single NAT Gateway Considerations

### Risks

- **Single point of failure**: If NAT gateway fails, private subnets lose internet
- **Cross-AZ data transfer**: $0.01/GB for traffic from other AZs
- **Bandwidth limit**: 45 Gbps (sufficient for demo)

### Mitigation

- AWS NAT Gateway has 99.9% SLA
- Automatic failover within AZ
- For production, use 1 NAT per AZ

### Monitoring

```bash
# Check NAT gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxxxx \
  --start-time 2025-11-29T00:00:00Z \
  --end-time 2025-11-29T23:59:59Z \
  --period 3600 \
  --statistics Sum \
  --region us-east-1
```

## Verification

### Check Node Types
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\\.kubernetes\\.io/instance-type,CAPACITY-TYPE:.metadata.labels.eks\\.amazonaws\\.com/capacityType
```

Expected output:
```
NAME                              INSTANCE-TYPE   CAPACITY-TYPE
ip-192-168-x-x.ec2.internal      t3.small        SPOT
ip-192-168-x-x.ec2.internal      t3.small        SPOT
ip-192-168-x-x.ec2.internal      t3.small        SPOT
```

### Check NAT Gateways
```bash
aws ec2 describe-nat-gateways --region us-east-1 --query 'NatGateways[?State==`available`].[NatGatewayId,SubnetId]' --output table
```

Expected: 1 NAT gateway

### Verify Applications
```bash
kubectl get pods -A
kubectl get ingress -A
```

All pods should be running and ingress should have ALB address.

## Rollback Plan

If issues occur:

### Restore NAT Gateways
```bash
# Create NAT gateway in each AZ
aws ec2 create-nat-gateway \
  --subnet-id subnet-xxxxx \
  --allocation-id eipalloc-xxxxx \
  --region us-east-1
```

### Switch to On-Demand
```bash
eksctl create nodegroup \
  --cluster=cicd-cluster \
  --name=general-ondemand \
  --node-type=t3.medium \
  --nodes=3 \
  --region=us-east-1
```

## Cost Monitoring

### Set up AWS Budget Alert

```bash
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

budget.json:
```json
{
  "BudgetName": "EKS-Monthly-Budget",
  "BudgetLimit": {
    "Amount": "200",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### Track Savings

```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

## Summary

**New Monthly Cost: ~$149**
- EKS Control Plane: $73
- 3x t3.small spot: $23
- 1x NAT Gateway: $33
- ALB: $20

**Savings: $134/month (47%)**

**Trade-offs:**
- Spot: 5% interruption risk (acceptable for demo)
- Single NAT: Single point of failure (acceptable for demo)
- t3.small: Less memory (2GB vs 4GB, sufficient for current workload)
