# Spring Boot Application Documentation

## Overview

Spring Boot 4.0 application with production-ready observability features.

## Technology Stack

- **Framework**: Spring Boot 4.0.0
- **Java Version**: 25 (Eclipse Temurin)
- **Build Tool**: Maven 3.9+ with wrapper
- **Observability**: Spring Boot Actuator + Micrometer Prometheus

## Project Structure

```
JavaApp/
├── src/
│   ├── main/
│   │   ├── java/com/jaystewwtest/
│   │   │   ├── StoreApplication.java      # Main application
│   │   │   ├── OrderService.java          # Business logic
│   │   │   └── StripePaymentService.java  # Payment service
│   │   └── resources/
│   │       ├── application.properties      # Configuration
│   │       └── static/
│   │           └── index.html              # Portfolio page
│   └── test/                               # Unit tests
├── pom.xml                                 # Dependencies
├── Dockerfile                              # Multi-stage build
└── .mvn/                                   # Maven wrapper
```

## Dependencies

```xml
<!-- Web Framework -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<!-- Observability -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>

<!-- Prometheus Metrics -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>

<!-- Testing -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

## Configuration

**application.properties**:
```properties
management.endpoints.web.exposure.include=health,info,prometheus,metrics
management.endpoint.health.show-details=always
management.metrics.export.prometheus.enabled=true
```

## Actuator Endpoints

- **Health**: `/actuator/health` - Application health status
- **Prometheus**: `/actuator/prometheus` - Metrics in Prometheus format
- **Metrics**: `/actuator/metrics` - Available metrics list
- **Info**: `/actuator/info` - Application information

## Local Development

### Run Application
```bash
cd JavaApp
./mvnw spring-boot:run
```

Access at: http://localhost:8080

### Run Tests
```bash
./mvnw test
```

### Build JAR
```bash
./mvnw clean package
java -jar target/store-0.0.1-SNAPSHOT.jar
```

### Build Docker Image
```bash
docker build -t spring-boot-app .
docker run -p 8080:8080 spring-boot-app
```

## Dockerfile

Multi-stage build for optimized image size:

**Stage 1: Build**
- Base: `eclipse-temurin:25-jdk-alpine`
- Copies Maven wrapper and dependencies
- Runs `./mvnw clean package -DskipTests`

**Stage 2: Runtime**
- Base: `eclipse-temurin:25-jre-alpine`
- Copies only the JAR file
- Exposes port 8080
- Final image: ~243MB

## Testing

```bash
# Run all tests
./mvnw test

# Run with coverage
./mvnw test jacoco:report

# Integration tests
./mvnw verify
```

## Troubleshooting

**Port already in use**:
```bash
lsof -ti:8080 | xargs kill -9
```

**Maven wrapper not executable**:
```bash
chmod +x mvnw
```

**Build fails**:
```bash
./mvnw clean install -U  # Force update dependencies
```
