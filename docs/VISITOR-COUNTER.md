# Visitor Counter Implementation

## Overview
The visitor counter tracks page visits and unique visitors without requiring an external database. It demonstrates rate limiting, session management, and RESTful API design.

## Architecture

### Components

**1. VisitorService** (`VisitorService.java`)
- In-memory storage using `AtomicLong` for thread-safe counters
- Tracks two metrics:
  - `totalVisitors`: Every page load (increments on each API call)
  - `uniqueVisitors`: First-time visitors only (based on cookie presence)
- Thread-safe operations ensure accuracy under concurrent load

**2. VisitorController** (`VisitorController.java`)
- REST endpoint: `GET /api/visitors`
- Returns JSON: `{"totalVisits": 123, "uniqueVisitors": 45, "isNewVisitor": true}`
- Cookie management:
  - Checks for `visitor_id` cookie
  - Creates new cookie for first-time visitors (365-day expiry)
  - Cookie persists across browser sessions

**3. RateLimitInterceptor** (`RateLimitInterceptor.java`)
- Implements token bucket algorithm via Bucket4j library
- Limit: 100 requests per minute per IP address
- IP extraction:
  - Reads `X-Forwarded-For` header (set by ALB)
  - Falls back to `RemoteAddr` if header missing
- Returns HTTP 429 (Too Many Requests) when limit exceeded
- Per-IP buckets stored in `ConcurrentHashMap`

**4. WebConfig** (`WebConfig.java`)
- Registers rate limit interceptor for `/api/**` paths
- Applies to all API endpoints automatically

## How It Works

### Request Flow

```
1. User loads homepage
   ↓
2. Browser executes JavaScript fetch('/api/visitors')
   ↓
3. Request passes through ALB → adds X-Forwarded-For header
   ↓
4. RateLimitInterceptor checks IP rate limit
   ├─ Under limit → Continue
   └─ Over limit → Return 429 error
   ↓
5. VisitorController processes request
   ├─ Increment totalVisitors counter
   ├─ Check for visitor_id cookie
   │  ├─ Cookie exists → Returning visitor
   │  └─ No cookie → New visitor
   │     ├─ Increment uniqueVisitors counter
   │     └─ Set visitor_id cookie (UUID)
   ↓
6. Return JSON response
   ↓
7. JavaScript updates badge: " 123 visits | 45 unique"
```

### Rate Limiting Details

**Token Bucket Algorithm:**
- Each IP gets a bucket with 100 tokens
- Each request consumes 1 token
- Bucket refills at 100 tokens per minute
- Allows bursts up to 100 requests, then throttles

**Why 100 requests/minute?**
- Normal browsing: 1-2 requests/minute
- Allows page refreshes without blocking
- Prevents automated scraping/abuse
- Protects cluster from scaling due to malicious traffic

### Cookie Strategy

**visitor_id Cookie:**
- Value: Random UUID (e.g., `a3f2c8d1-4b5e-6789-0abc-def123456789`)
- Expiry: 365 days
- Path: `/` (entire site)
- Not HttpOnly: Accessible to JavaScript (not security-sensitive)
- Not Secure: Works over HTTP (for demo purposes)

**Limitations:**
- Cleared if user deletes cookies
- Different browsers = different visitors
- Incognito mode = new visitor each time
- Not persistent across pod restarts (in-memory storage)

## Trade-offs

### In-Memory Storage
**Pros:**
- No external database required
- Fast (nanosecond access time)
- Simple implementation
- No additional infrastructure cost

**Cons:**
- Resets on pod restart/deployment
- Not shared across multiple pods
- Lost if pod crashes

**Why acceptable for demo:**
- Demonstrates API design and rate limiting
- Shows Spring Boot service layer patterns
- Avoids RDS/DynamoDB complexity
- Sufficient for portfolio showcase

### Alternative Approaches

**For production:**
1. **Redis/ElastiCache**: Shared counter across pods, persists through restarts
2. **DynamoDB**: Serverless, highly available, atomic counters
3. **RDS**: Relational database with transactions
4. **CloudWatch Metrics**: Native AWS monitoring

## Monitoring

### Prometheus Metrics
The visitor counter automatically exposes metrics via Spring Boot Actuator:

```
# Total API requests
http_server_requests_seconds_count{uri="/api/visitors"}

# Request duration
http_server_requests_seconds_sum{uri="/api/visitors"}

# Rate limit rejections (HTTP 429)
http_server_requests_seconds_count{status="429"}
```

### Grafana Queries
```promql
# Requests per minute
rate(http_server_requests_seconds_count{uri="/api/visitors"}[1m]) * 60

# Rate limit hit rate
rate(http_server_requests_seconds_count{uri="/api/visitors",status="429"}[5m])
```

## Testing

### Manual Testing

**Test visitor counter:**
```bash
curl http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/api/visitors
```

**Test rate limiting:**
```bash
for i in {1..101}; do
  curl -s http://k8s-mainalb-6fc2b61fbe-699915898.us-east-1.elb.amazonaws.com/api/visitors
done
# Request 101 should return 429 error
```

**Test unique visitor tracking:**
```bash
# First request (new visitor)
curl -c cookies.txt http://localhost/api/visitors
# Returns: {"totalVisits":1,"uniqueVisitors":1,"isNewVisitor":true}

# Second request (returning visitor)
curl -b cookies.txt http://localhost/api/visitors
# Returns: {"totalVisits":2,"uniqueVisitors":1,"isNewVisitor":false}
```

## Security Considerations

### Rate Limiting
- Prevents DDoS attacks
- Stops automated scraping
- Protects backend resources
- Prevents cost escalation from autoscaling

### Cookie Security
- Not used for authentication (no security risk)
- No sensitive data stored
- SameSite policy prevents CSRF
- Could add Secure flag for HTTPS-only

### IP Spoofing
- Trusts X-Forwarded-For header from ALB
- ALB is trusted source (within VPC)
- Not vulnerable to client-side spoofing
- For public APIs, validate header source

## Future Enhancements

1. **Persistent Storage**: Add Redis for cross-pod sharing
2. **Analytics**: Track page views, referrers, user agents
3. **Geolocation**: Show visitor locations on map
4. **Time Series**: Store hourly/daily visit trends
5. **Admin Dashboard**: View real-time visitor stats
6. **Custom Metrics**: Export to Prometheus for alerting
