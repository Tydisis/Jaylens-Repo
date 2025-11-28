# TLS/HTTPS Setup Guide

## Prerequisites
- A domain name (e.g., example.com)
- Domain DNS pointing to the ALB

## Option 1: AWS Certificate Manager (Recommended)

**Steps:**

1. **Request certificate in ACM:**
```bash
aws acm request-certificate \
  --domain-name your-domain.com \
  --validation-method DNS \
  --region us-east-1
```

2. **Validate domain ownership:**
   - Go to ACM console
   - Add the CNAME records to your DNS provider

3. **Get certificate ARN:**
```bash
aws acm list-certificates --region us-east-1
```

4. **Update ingress:**
   - Edit `k8s/ingress-tls.yaml`
   - Replace `YOUR-CERT-ID` with your certificate ARN
   - Replace `your-domain.com` with your actual domain

5. **Apply:**
```bash
kubectl apply -f k8s/ingress-tls.yaml
```

6. **Update DNS:**
   - Create A record or CNAME pointing to ALB hostname
   - Get ALB: `kubectl get ingress spring-boot-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`

## Option 2: cert-manager with Let's Encrypt (Free)

**Steps:**

1. **Install cert-manager:**
```bash
./k8s/setup-tls.sh
```

2. **Update ingress:**
   - Edit `k8s/ingress-certmanager.yaml`
   - Replace `your-domain.com` with your actual domain

3. **Point DNS to ALB:**
   - Create A record or CNAME pointing to ALB hostname

4. **Apply ingress:**
```bash
kubectl apply -f k8s/ingress-certmanager.yaml
```

5. **Verify certificate:**
```bash
kubectl get certificate
kubectl describe certificate spring-boot-tls
```

Certificate will be automatically issued and renewed by Let's Encrypt.

## Verify HTTPS

Once configured, access your site:
```
https://your-domain.com
```

HTTP traffic will automatically redirect to HTTPS.

## Troubleshooting

**Check certificate status:**
```bash
kubectl get certificate -n default
kubectl describe certificate spring-boot-tls
```

**Check ingress:**
```bash
kubectl describe ingress spring-boot-app
```

**Check ALB listeners:**
```bash
aws elbv2 describe-listeners \
  --load-balancer-arn $(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-default-springbo')].LoadBalancerArn" \
  --output text --region us-east-1) \
  --region us-east-1
```
