# Database Integration

## Overview

The application uses PostgreSQL for persistent data storage, demonstrating database integration, JPA/Hibernate ORM, and CRUD operations.

## Architecture

```
Spring Boot App (2 replicas)
        ↓
PostgreSQL Service (ClusterIP)
        ↓
PostgreSQL Pod (1 replica)
        ↓
PersistentVolume (5GB EBS)
```

## Components

### Database
- **Engine**: PostgreSQL 16 (Alpine)
- **Storage**: 5GB EBS-backed PersistentVolume
- **Replication**: Single instance (suitable for demo)
- **Backup**: Manual snapshots via EBS

### Application Layer
- **ORM**: Spring Data JPA with Hibernate
- **Connection Pool**: HikariCP (Spring Boot default)
- **Schema Management**: Hibernate auto-update

## Guestbook Feature

### API Endpoints

**GET /api/guestbook**
- Returns last 10 entries
- Ordered by creation date (newest first)
- No authentication required

```bash
curl http://YOUR-ALB-DNS/api/guestbook
```

Response:
```json
[
  {
    "id": 1,
    "name": "John Doe",
    "message": "Great demo!",
    "createdAt": "2025-11-28T20:30:00"
  }
]
```

**POST /api/guestbook**
- Creates new entry
- Validates name and message
- Rate limited (100 req/min per IP)

```bash
curl -X POST http://YOUR-ALB-DNS/api/guestbook \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","message":"Great demo!"}'
```

### Validation Rules
- Name: Required, non-empty
- Message: Required, max 500 characters
- Automatic timestamp on creation

## Deployment

### 1. Deploy PostgreSQL

```bash
kubectl apply -f k8s/postgres.yaml
```

This creates:
- PersistentVolumeClaim (5GB)
- Secret with database credentials
- PostgreSQL deployment
- ClusterIP service

### 2. Verify PostgreSQL

```bash
# Check pod status
kubectl get pods -l app=postgres

# Check logs
kubectl logs -l app=postgres

# Test connection
kubectl exec -it deployment/postgres -- psql -U postgres -d guestbook -c '\dt'
```

### 3. Update Application

The deployment already includes database environment variables:
- `DATABASE_URL`: Connection string
- `DATABASE_USERNAME`: From secret
- `DATABASE_PASSWORD`: From secret

Redeploy application:
```bash
kubectl rollout restart deployment/spring-boot-app
```

### 4. Verify Integration

```bash
# Check app logs for database connection
kubectl logs -l app=spring-boot-app | grep -i "database\|postgres"

# Test API
curl http://YOUR-ALB-DNS/api/guestbook
```

## Database Schema

### guestbook_entries Table

| Column     | Type         | Constraints           |
|------------|--------------|----------------------|
| id         | BIGSERIAL    | PRIMARY KEY          |
| name       | VARCHAR(255) | NOT NULL             |
| message    | VARCHAR(500) | NOT NULL             |
| created_at | TIMESTAMP    | NOT NULL, DEFAULT NOW|

Auto-created by Hibernate on first application startup.

## Configuration

### application.properties

```properties
# Database URL (overridden by env var)
spring.datasource.url=${DATABASE_URL:jdbc:postgresql://localhost:5432/guestbook}
spring.datasource.username=${DATABASE_USERNAME:postgres}
spring.datasource.password=${DATABASE_PASSWORD:postgres}

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
```

### Environment Variables

Set in Kubernetes deployment:
- `DATABASE_URL`: Full JDBC connection string
- `DATABASE_USERNAME`: Database user
- `DATABASE_PASSWORD`: Database password

## Connection Pooling

**HikariCP** (Spring Boot default):
- Maximum pool size: 10 connections
- Minimum idle: 10 connections
- Connection timeout: 30 seconds
- Idle timeout: 10 minutes

Suitable for 2 application replicas with moderate traffic.

## Monitoring

### Database Metrics

Exposed via Spring Boot Actuator:
```promql
# Active database connections
hikaricp_connections_active{pool="HikariPool-1"}

# Connection acquisition time
hikaricp_connections_acquire_seconds_sum
```

### Health Check

Database health included in `/actuator/health`:
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    }
  }
}
```

## Troubleshooting

### Application Can't Connect

**Check PostgreSQL is running:**
```bash
kubectl get pods -l app=postgres
kubectl logs -l app=postgres
```

**Verify service DNS:**
```bash
kubectl exec -it deployment/spring-boot-app -- nslookup postgres
```

**Check credentials:**
```bash
kubectl get secret postgres-secret -o yaml
```

### Connection Pool Exhausted

**Symptoms:**
- Slow API responses
- Timeout errors
- High connection wait time

**Solution:**
Increase pool size in application.properties:
```properties
spring.datasource.hikari.maximum-pool-size=20
```

### Database Disk Full

**Check PVC usage:**
```bash
kubectl exec -it deployment/postgres -- df -h /var/lib/postgresql/data
```

**Expand PVC:**
```bash
kubectl patch pvc postgres-pvc -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

## Production Considerations

### High Availability

**Current**: Single PostgreSQL instance
**Production**: Use Amazon RDS PostgreSQL
- Multi-AZ deployment
- Automated backups
- Read replicas
- Managed updates

### Backup Strategy

**Manual Backup:**
```bash
kubectl exec deployment/postgres -- pg_dump -U postgres guestbook > backup.sql
```

**Restore:**
```bash
kubectl exec -i deployment/postgres -- psql -U postgres guestbook < backup.sql
```

**Automated**: Use RDS automated backups or Velero for K8s resources

### Security

**Current Setup:**
- Credentials in Kubernetes Secret (base64 encoded)
- ClusterIP service (not exposed externally)
- No SSL/TLS

**Production Recommendations:**
- Use AWS Secrets Manager
- Enable SSL/TLS for connections
- Rotate credentials regularly
- Use IAM database authentication (RDS)
- Network policies to restrict access

### Performance Optimization

1. **Indexing**: Add indexes for frequently queried columns
2. **Connection Pooling**: Tune based on load testing
3. **Query Optimization**: Use EXPLAIN ANALYZE
4. **Caching**: Add Redis for frequently accessed data
5. **Read Replicas**: Offload read traffic (RDS)

## Migration to RDS

### Benefits
- Managed service (no maintenance)
- Automated backups
- Multi-AZ high availability
- Read replicas for scaling
- Monitoring and alerting

### Steps

1. **Create RDS Instance**
```bash
aws rds create-db-instance \
  --db-instance-identifier guestbook-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username postgres \
  --master-user-password SECURE_PASSWORD \
  --allocated-storage 20
```

2. **Update Application**
```yaml
env:
- name: DATABASE_URL
  value: "jdbc:postgresql://guestbook-db.xxxxx.us-east-1.rds.amazonaws.com:5432/guestbook"
```

3. **Migrate Data**
```bash
pg_dump -h localhost -U postgres guestbook | \
  psql -h guestbook-db.xxxxx.us-east-1.rds.amazonaws.com -U postgres guestbook
```

## Cost Estimation

**Current (EKS):**
- 5GB EBS volume: $0.50/month
- PostgreSQL pod: Included in node costs

**RDS Alternative:**
- db.t3.micro: $15/month
- 20GB storage: $2/month
- Backups: $0.10/GB/month
- **Total: ~$20/month**

## Next Steps

1. Add database migrations (Flyway/Liquibase)
2. Implement soft deletes
3. Add pagination for large datasets
4. Create admin interface for moderation
5. Add full-text search
6. Implement caching layer (Redis)
