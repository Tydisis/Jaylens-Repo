# Log Aggregation with Fluent Bit

## Overview

Fluent Bit collects logs from all containers and ships them to Amazon CloudWatch Logs for centralized storage, search, and analysis.

## Architecture

```
Container Logs (/var/log/containers/*.log)
        ↓
Fluent Bit DaemonSet (1 pod per node)
        ↓
CloudWatch Logs (/aws/eks/cicd-cluster/application)
        ↓
CloudWatch Insights (Query & Analysis)
```

## Components

### Fluent Bit DaemonSet
- **Image**: amazon/aws-for-fluent-bit:2.32.2
- **Deployment**: 1 pod per node (DaemonSet)
- **Resources**: 100Mi memory, 100m CPU
- **IAM**: IRSA with CloudWatch Logs permissions

### CloudWatch Log Group
- **Name**: `/aws/eks/cicd-cluster/application`
- **Retention**: Default (never expire)
- **Stream prefix**: `from-fluent-bit-`

## Configuration

### Input Plugin
- **Type**: tail
- **Path**: `/var/log/containers/*.log`
- **Parser**: docker (JSON format)
- **Refresh**: Every 5 seconds
- **Buffer**: 5MB per file

### Filter Plugin
- **Type**: kubernetes
- **Enrichment**: Adds pod name, namespace, labels, annotations
- **Log merging**: Combines multi-line logs
- **Exclusions**: Respects `fluentbit.io/exclude: "true"` annotation

### Output Plugin
- **Type**: cloudwatch_logs
- **Region**: us-east-1
- **Auto-create**: Creates log group if missing
- **Stream naming**: `from-fluent-bit-{pod_name}`

## Viewing Logs

### CloudWatch Console

1. Go to: https://console.aws.amazon.com/cloudwatch/
2. Navigate to: Logs → Log groups
3. Find: `/aws/eks/cicd-cluster/application`
4. Click on any log stream

### AWS CLI

**List log streams:**
```bash
aws logs describe-log-streams \
  --log-group-name /aws/eks/cicd-cluster/application \
  --order-by LastEventTime \
  --descending \
  --max-items 10
```

**Tail logs:**
```bash
aws logs tail /aws/eks/cicd-cluster/application --follow
```

**Get specific pod logs:**
```bash
aws logs tail /aws/eks/cicd-cluster/application \
  --filter-pattern "spring-boot-app" \
  --follow
```

### CloudWatch Insights Queries

**Error logs in last hour:**
```
fields @timestamp, kubernetes.pod_name, log
| filter log like /ERROR|Exception/
| sort @timestamp desc
| limit 100
```

**Spring Boot application logs:**
```
fields @timestamp, kubernetes.pod_name, log
| filter kubernetes.pod_name like /spring-boot-app/
| sort @timestamp desc
| limit 100
```

**HTTP request logs:**
```
fields @timestamp, kubernetes.pod_name, log
| filter log like /GET|POST|PUT|DELETE/
| parse log /(?<method>GET|POST|PUT|DELETE) (?<path>\/[^ ]*)/
| stats count() by method, path
```

**Database connection errors:**
```
fields @timestamp, log
| filter log like /postgres|database|connection/
| filter log like /error|failed|exception/i
| sort @timestamp desc
```

## Log Format

### Raw Container Log
```json
{
  "log": "2025-11-29T18:30:00.123Z INFO --- Started DemoApplication\n",
  "stream": "stdout",
  "time": "2025-11-29T18:30:00.123456789Z"
}
```

### Enriched by Fluent Bit
```json
{
  "log": "2025-11-29T18:30:00.123Z INFO --- Started DemoApplication",
  "kubernetes": {
    "pod_name": "spring-boot-app-64c47467b5-glgzr",
    "namespace_name": "default",
    "pod_id": "abc123...",
    "labels": {
      "app": "spring-boot-app"
    },
    "host": "ip-192-168-118-107.ec2.internal",
    "container_name": "spring-boot-app"
  }
}
```

## Monitoring Fluent Bit

### Check DaemonSet Status
```bash
kubectl get daemonset fluent-bit -n kube-system
```

Expected: 1 pod per node (3 total)

### Check Pod Logs
```bash
kubectl logs -n kube-system -l app=fluent-bit --tail=50
```

Look for:
- `[output:cloudwatch_logs:cloudwatch_logs.0] Created log stream`
- No error messages

### Verify CloudWatch Delivery
```bash
# Check recent log events
aws logs get-log-events \
  --log-group-name /aws/eks/cicd-cluster/application \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /aws/eks/cicd-cluster/application \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --query 'logStreams[0].logStreamName' \
    --output text) \
  --limit 10
```

## Cost

### CloudWatch Logs Pricing (us-east-1)
- **Ingestion**: $0.50/GB
- **Storage**: $0.03/GB/month
- **Insights queries**: $0.005/GB scanned

### Estimated Monthly Cost
- **Log volume**: ~2-5 GB/month (low traffic demo)
- **Ingestion**: $1-2.50
- **Storage**: $0.06-0.15
- **Queries**: $0.10-0.50
- **Total**: ~$2-3/month

### Cost Optimization
- Set retention policy (7, 30, 90 days)
- Filter out verbose logs
- Use log sampling for high-volume apps

## Retention Policy

**Set 7-day retention:**
```bash
aws logs put-retention-policy \
  --log-group-name /aws/eks/cicd-cluster/application \
  --retention-in-days 7
```

**Options**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653 days

## Filtering Logs

### Exclude Noisy Pods

Add annotation to pod:
```yaml
metadata:
  annotations:
    fluentbit.io/exclude: "true"
```

### Filter by Log Level

Update Fluent Bit config:
```
[FILTER]
    Name    grep
    Match   kube.*
    Regex   log (ERROR|WARN|INFO)
```

## Troubleshooting

### No Logs in CloudWatch

**Check Fluent Bit pods:**
```bash
kubectl get pods -n kube-system -l app=fluent-bit
kubectl logs -n kube-system -l app=fluent-bit
```

**Verify IAM permissions:**
```bash
kubectl describe sa fluent-bit -n kube-system
```

Should show annotation: `eks.amazonaws.com/role-arn`

**Test CloudWatch access:**
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/eks/cicd-cluster
```

### High CloudWatch Costs

**Check log volume:**
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/cicd-cluster \
  --query 'logGroups[*].[logGroupName,storedBytes]' \
  --output table
```

**Reduce volume:**
- Add log level filtering (ERROR/WARN only)
- Exclude health check logs
- Set shorter retention period

### Logs Not Appearing

**Check Fluent Bit errors:**
```bash
kubectl logs -n kube-system daemonset/fluent-bit | grep -i error
```

**Common issues:**
- IAM permissions missing
- Log group creation failed
- Network connectivity issues

## Integration with Grafana

### Add CloudWatch Data Source

1. Login to Grafana: http://52.1.43.215/grafana/ (continuous/improvement)
2. Configuration → Data sources → Add data source
3. Select "CloudWatch"
4. Configure:
   - **Auth Provider**: AWS SDK Default
   - **Default Region**: us-east-1
5. Click "Save & test"

### Import Log Dashboard

Pre-built dashboard available at: `k8s/grafana-logs-dashboard.json`

**Import steps:**
```bash
# Copy dashboard to your local machine
kubectl cp k8s/grafana-logs-dashboard.json default/$(kubectl get pod -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}'):/tmp/

# Or import via Grafana UI:
# 1. Dashboards → Import
# 2. Upload JSON file: k8s/grafana-logs-dashboard.json
# 3. Select CloudWatch data source
# 4. Click Import
```

**Dashboard includes:**
- Recent Error Logs (last 50 errors/exceptions)
- Log Volume by Level (ERROR/WARN over time)
- HTTP Requests by Method (GET/POST/PUT/DELETE)
- Spring Boot Application Logs (last 100 entries)
- Database Connection Errors
- Top Request Paths (most accessed endpoints)
- Logs by Pod (volume per pod)

## Best Practices

1. **Structured Logging**: Use JSON format in application
2. **Log Levels**: Use appropriate levels (ERROR, WARN, INFO, DEBUG)
3. **Correlation IDs**: Add request IDs for tracing
4. **Sensitive Data**: Never log passwords, tokens, PII
5. **Retention**: Set appropriate retention based on compliance needs
6. **Sampling**: Sample high-volume logs (e.g., health checks)

## Next Steps

1. Set log retention policy (7-30 days)
2. Create CloudWatch alarms for errors
3. Build Grafana dashboards for log visualization
4. Add structured logging to Spring Boot app
5. Implement log sampling for high-volume endpoints
