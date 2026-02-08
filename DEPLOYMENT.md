# Deployment Guide - Diabetes Risk Prediction Model

## Table of Contents
1. [Development Environment](#development-environment)
2. [Staging Environment](#staging-environment)
3. [Production Environment](#production-environment)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Monitoring & Alerting](#monitoring--alerting)
6. [Security Best Practices](#security-best-practices)
7. [Scaling Strategies](#scaling-strategies)

## Development Environment

### Local Setup
```bash
# 1. Clone repository
git clone <repository-url>
cd diabetes_risk_model

# 2. Run setup
Rscript setup.R

# 3. Train model
make train

# 4. Run tests
make test

# 5. Start API
make api
```

### Development Workflow
1. Make changes to code
2. Run tests: `make test`
3. Test locally: `Rscript run_api.R`
4. Commit changes with descriptive messages
5. Push to feature branch

## Staging Environment

### Prerequisites
- Linux server (Ubuntu 20.04+ recommended)
- Docker & Docker Compose
- 2GB+ RAM, 2+ CPU cores
- SSL certificate (Let's Encrypt)

### Deployment Steps

#### 1. Server Setup
```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

#### 2. Application Deployment
```bash
# Transfer files
scp -r diabetes_risk_model user@staging-server:/opt/

# SSH into server
ssh user@staging-server

# Navigate to project
cd /opt/diabetes_risk_model

# Train model
docker run --rm -v $(pwd):/app rocker/r-ver:4.3.2 \
  Rscript /app/train_model.R

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

#### 3. Nginx Reverse Proxy (Optional but Recommended)
```nginx
# /etc/nginx/sites-available/diabetes-api
server {
    listen 80;
    server_name staging-api.example.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Enable site
sudo ln -s /etc/nginx/sites-available/diabetes-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 4. SSL Setup with Let's Encrypt
```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d staging-api.example.com

# Auto-renewal is configured automatically
```

## Production Environment

### High-Availability Setup

#### Architecture
```
                     [Load Balancer]
                           |
        +------------------+------------------+
        |                  |                  |
   [API Node 1]       [API Node 2]       [API Node 3]
        |                  |                  |
        +------------------+------------------+
                           |
                    [Shared Storage]
                     (Models, Logs)
```

#### Load Balancer Configuration (HAProxy)
```haproxy
# /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 4096

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend diabetes_api
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/diabetes-api.pem
    redirect scheme https if !{ ssl_fc }
    default_backend api_servers

backend api_servers
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server node1 10.0.1.10:8000 check
    server node2 10.0.1.11:8000 check
    server node3 10.0.1.12:8000 check
```

#### Docker Compose for Production
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  diabetes-api:
    image: your-registry.com/diabetes-api:${VERSION}
    restart: always
    environment:
      - R_LIBS_USER=/usr/local/lib/R/site-library
      - LOG_LEVEL=INFO
    volumes:
      - /mnt/shared/models:/app/models:ro
      - /mnt/shared/logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}

volumes:
  prometheus_data:
  grafana_data:
```

## CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup R
        uses: r-lib/actions/setup-r@v2
        with:
          r-version: '4.3.2'
      
      - name: Install dependencies
        run: |
          Rscript -e "install.packages(c('mlbench', 'tidyverse', 'testthat'))"
      
      - name: Run tests
        run: Rscript tests.R
  
  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: |
          docker build -t diabetes-api:${{ github.sha }} .
          docker tag diabetes-api:${{ github.sha }} diabetes-api:latest
      
      - name: Push to registry
        run: |
          echo ${{ secrets.REGISTRY_PASSWORD }} | docker login -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
          docker push diabetes-api:${{ github.sha }}
          docker push diabetes-api:latest
  
  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Deploy to staging
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/diabetes_risk_model
            docker-compose pull
            docker-compose up -d
  
  deploy-production:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Deploy to production
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /opt/diabetes_risk_model
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d --no-deps diabetes-api
```

## Monitoring & Alerting

### Prometheus Configuration
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'diabetes-api'
    static_configs:
      - targets: ['diabetes-api:8000']
```

### Alerting Rules
```yaml
# monitoring/alert-rules.yml
groups:
  - name: diabetes_api_alerts
    interval: 30s
    rules:
      - alert: APIDown
        expr: up{job="diabetes-api"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "API instance is down"
      
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
      
      - alert: DataDriftDetected
        expr: data_drift_detected > 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Data drift detected in production"
```

### Email Alerts Setup
```r
# Add to monitor.R
send_alert <- function(message, severity = "warning") {
  if (config$monitoring$alert_email != "") {
    # Using sendmailR or other email package
    library(sendmailR)
    
    sendmail(
      from = "alerts@diabetes-api.com",
      to = config$monitoring$alert_email,
      subject = sprintf("[%s] Diabetes API Alert", toupper(severity)),
      msg = message
    )
    
    logger::log_info("Alert sent: {message}")
  }
}
```

## Security Best Practices

### 1. API Authentication
```r
# Add to api.R
#* @filter auth
function(req, res) {
  api_key <- req$HTTP_X_API_KEY
  
  if (is.null(api_key) || !validate_api_key(api_key)) {
    res$status <- 401
    return(list(error = "Unauthorized"))
  }
  
  plumber::forward()
}

validate_api_key <- function(key) {
  valid_keys <- readLines("api_keys.txt")
  return(key %in% valid_keys)
}
```

### 2. Rate Limiting
```r
# Add rate limiting middleware
library(ratelimitr)

rate_limiter <- limit_rate(
  function() TRUE,
  rate(n = 100, period = 60)  # 100 requests per minute
)

#* @filter rate_limit
function(req, res) {
  if (!rate_limiter()) {
    res$status <- 429
    return(list(error = "Too many requests"))
  }
  plumber::forward()
}
```

### 3. Input Sanitization
Already implemented in `predict.R` via `validate_input()`

### 4. HTTPS Only
Configure in production environment with SSL certificates

### 5. Environment Variables for Secrets
```bash
# .env file (never commit this!)
DATABASE_PASSWORD=secure_password
API_SECRET_KEY=your_secret_key
REGISTRY_TOKEN=docker_registry_token

# Load in R
Sys.getenv("DATABASE_PASSWORD")
```

## Scaling Strategies

### Horizontal Scaling
```bash
# Scale up API instances
docker-compose -f docker-compose.prod.yml up -d --scale diabetes-api=5

# Or with Kubernetes
kubectl scale deployment diabetes-api --replicas=5
```

### Caching Layer
```r
# Add Redis caching
library(redux)
redis <- hiredis()

cached_predict <- function(patient_data) {
  # Create cache key
  cache_key <- digest::digest(patient_data)
  
  # Check cache
  cached_result <- redis$GET(cache_key)
  if (!is.null(cached_result)) {
    return(jsonlite::fromJSON(cached_result))
  }
  
  # Make prediction
  result <- predictor$predict_diabetes(patient_data)
  
  # Cache result (TTL: 1 hour)
  redis$SETEX(cache_key, 3600, jsonlite::toJSON(result))
  
  return(result)
}
```

### Database for Logging
```r
# Add PostgreSQL connection
library(DBI)
library(RPostgres)

con <- dbConnect(
  Postgres(),
  dbname = "diabetes_db",
  host = "localhost",
  port = 5432,
  user = "postgres",
  password = Sys.getenv("DB_PASSWORD")
)

# Log predictions
log_prediction <- function(input, output) {
  dbExecute(
    con,
    "INSERT INTO predictions (input_data, prediction, probability, timestamp)
     VALUES ($1, $2, $3, NOW())",
    params = list(
      jsonlite::toJSON(input),
      output$prediction,
      output$probability
    )
  )
}
```

## Health Checks & Readiness

### Liveness Probe
```yaml
# kubernetes deployment
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10
```

### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /model/info
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Backup & Disaster Recovery

### Model Backup
```bash
# Daily model backup
0 2 * * * rsync -avz /opt/diabetes_risk_model/models/ /backup/models/$(date +\%Y\%m\%d)/
```

### Database Backup
```bash
# Daily database backup
0 3 * * * pg_dump diabetes_db | gzip > /backup/db/diabetes_db_$(date +\%Y\%m\%d).sql.gz
```

## Rollback Procedure

```bash
# Rollback to previous version
docker-compose -f docker-compose.prod.yml down
docker tag diabetes-api:previous diabetes-api:latest
docker-compose -f docker-compose.prod.yml up -d

# Restore model
cp /backup/models/YYYYMMDD/* /opt/diabetes_risk_model/models/
```

---

**Remember**: Always test in staging before deploying to production!
