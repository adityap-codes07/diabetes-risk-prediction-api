# Diabetes Risk Prediction Model - Quick Reference

## 📁 Project Structure

```
diabetes_risk_model/
├── Core Application Files
│   ├── config.yaml              # Configuration settings
│   ├── utils.R                  # Utility functions & helpers
│   ├── train_model.R           # Model training pipeline
│   ├── predict.R               # Prediction logic & DiabetesPredictor class
│   ├── api.R                   # REST API endpoints (Plumber)
│   ├── run_api.R              # API server startup script
│   └── monitor.R              # Monitoring & drift detection
│
├── Testing & Examples
│   ├── tests.R                # Comprehensive test suite
│   ├── client_example.R       # API client examples (R, Python, curl)
│   └── setup.R                # Environment setup script
│
├── Deployment
│   ├── Dockerfile             # Docker container configuration
│   ├── docker-compose.yml     # Docker Compose orchestration
│   ├── Makefile              # Command shortcuts
│   ├── .gitignore            # Git ignore rules
│   ├── README.md             # Full documentation
│   └── DEPLOYMENT.md         # Deployment guide
│
└── Output Directories (auto-created)
    ├── results/              # Training results & CSV outputs
    ├── models/               # Saved model files (.rds)
    ├── logs/                 # Application logs
    ├── plots/                # Generated visualizations
    └── reports/              # Evaluation reports
```

## 🚀 Quick Start Commands

```bash
# Setup environment
Rscript setup.R

# Using Makefile (recommended)
make install    # Install dependencies
make train      # Train model
make test       # Run tests
make api        # Start API server
make all        # Install + train + test

# Manual execution
Rscript train_model.R        # Train model
Rscript tests.R             # Run tests
Rscript run_api.R           # Start API

# Docker deployment
docker-compose up -d        # Start all services
docker-compose logs -f      # View logs
docker-compose down         # Stop services
```

## 📊 Key Features

### 1. **Training Pipeline** (`train_model.R`)
- Data loading & preprocessing
- Missing value handling (3 strategies)
- Outlier detection (IQR & Z-score methods)
- Train/validation/test split
- Linear & logistic regression models
- Model evaluation (AUC, accuracy, sensitivity, specificity)
- Automated visualization generation
- Model artifact saving

### 2. **Prediction API** (`api.R`)
- `/health` - Health check
- `/model/info` - Model metadata
- `/predict` - Single prediction
- `/predict/batch` - Batch predictions
- `/predict/bloodsugar` - Blood sugar estimation
- `/docs` - API documentation

### 3. **Model Monitoring** (`monitor.R`)
- Data drift detection (KS test, mean shift)
- Performance monitoring
- Automated alerting
- Reference statistics management

### 4. **Comprehensive Testing** (`tests.R`)
- Configuration validation
- Data processing tests
- Model training verification
- Prediction accuracy tests
- Input validation checks

## 🔧 Configuration Options

Edit `config.yaml` to customize:

```yaml
# Model settings
model:
  version: "1.0.0"
  random_seed: 42

# Data processing
data:
  test_size: 0.2
  validation_size: 0.2
  missing_value_threshold: 0.3

# Performance thresholds
validation:
  min_auc: 0.70
  min_sensitivity: 0.65
  min_specificity: 0.65

# API settings
api:
  host: "0.0.0.0"
  port: 8000
  max_batch_size: 1000
```

## 📡 API Usage Examples

### cURL
```bash
# Single prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"Age": 50, "BMI": 32.5, "BloodSugar": 148, "insulin": 125, "pressure": 88, "pregnant": 2}'
```

### R
```r
library(httr)
response <- POST(
  "http://localhost:8000/predict",
  body = list(Age = 50, BMI = 32.5, BloodSugar = 148, 
              insulin = 125, pressure = 88, pregnant = 2),
  encode = "json"
)
result <- content(response)$data
```

### Python
```python
import requests
result = requests.post(
    "http://localhost:8000/predict",
    json={"Age": 50, "BMI": 32.5, "BloodSugar": 148,
          "insulin": 125, "pressure": 88, "pregnant": 2}
).json()["data"]
```

## 📈 Model Performance

**Expected Metrics:**
- AUC-ROC: 0.80-0.85
- Accuracy: 0.75-0.80
- Sensitivity: 0.70-0.75
- Specificity: 0.75-0.80

**Input Features:**
1. Age (0-120 years)
2. BMI (10-80 kg/m²)
3. Blood Sugar (0-500 mg/dL)
4. Insulin level (≥0)
5. Blood Pressure (0-300 mmHg)
6. Number of pregnancies (≥0)

**Output:**
- Prediction: "pos" or "neg"
- Probability: 0.0 to 1.0
- Risk Category: "Low", "Medium", or "High"
- Confidence: 0.0 to 1.0

## 🔍 Troubleshooting

| Issue | Solution |
|-------|----------|
| Models not found | Run `Rscript train_model.R` first |
| API won't start | Check if port 8000 is available |
| Package errors | Run `Rscript setup.R` to install dependencies |
| Permission denied | Check file permissions: `chmod +x run_api.R` |
| Docker issues | Ensure Docker is running: `docker ps` |

## 🛡️ Security Checklist

- [ ] Enable HTTPS in production
- [ ] Implement API authentication
- [ ] Add rate limiting
- [ ] Validate all inputs
- [ ] Use environment variables for secrets
- [ ] Regular security updates
- [ ] Monitor for anomalies
- [ ] Implement audit logging

## 📦 Deployment Checklist

**Development:**
- [ ] Code tested locally
- [ ] All tests passing
- [ ] Documentation updated

**Staging:**
- [ ] Models trained and validated
- [ ] API accessible
- [ ] Monitoring configured
- [ ] Performance benchmarks met

**Production:**
- [ ] Load balancer configured
- [ ] SSL certificate installed
- [ ] Backups automated
- [ ] Alerts configured
- [ ] Rollback plan ready

## 🎯 Key Improvements Over Original Code

| Aspect | Original | Production-Ready |
|--------|----------|------------------|
| **Structure** | Single script | Modular architecture |
| **Error Handling** | None | Comprehensive try-catch |
| **Logging** | print() statements | Structured logging (logger) |
| **Configuration** | Hard-coded | YAML configuration |
| **Testing** | None | Automated test suite |
| **Deployment** | Manual | Docker + Docker Compose |
| **API** | None | REST API with Plumber |
| **Monitoring** | None | Drift detection + alerts |
| **Documentation** | Minimal | Comprehensive guides |
| **Validation** | None | Input validation + metrics |

## 📚 File Descriptions

| File | Purpose | When to Use |
|------|---------|-------------|
| `train_model.R` | Train & evaluate models | Initial training, retraining |
| `predict.R` | Make predictions | Called by API or directly |
| `api.R` | API endpoints | Production deployment |
| `run_api.R` | Start API server | Launch API service |
| `monitor.R` | Track performance | Production monitoring |
| `tests.R` | Validate code | Development, CI/CD |
| `setup.R` | Initialize environment | First-time setup |
| `client_example.R` | API usage examples | Learning, integration |

## 🔄 Typical Workflow

1. **Initial Setup**
   ```bash
   Rscript setup.R
   make train
   make test
   ```

2. **Development Cycle**
   ```bash
   # Make code changes
   make test
   Rscript run_api.R  # Test locally
   ```

3. **Deployment**
   ```bash
   docker-compose up -d
   # Verify: curl http://localhost:8000/health
   ```

4. **Monitoring**
   ```r
   source("monitor.R")
   monitor <- ModelMonitor$new()
   monitor$detect_drift(new_data)
   ```

5. **Retraining (when needed)**
   ```bash
   make train
   docker-compose restart
   ```

## 💡 Best Practices

1. **Always validate before production**
   - Test on staging first
   - Check all metrics pass thresholds
   - Review monitoring dashboards

2. **Keep models versioned**
   - Save model artifacts with timestamps
   - Maintain model metadata
   - Document performance metrics

3. **Monitor continuously**
   - Track data drift
   - Monitor API latency
   - Alert on degradation

4. **Regular maintenance**
   - Retrain models periodically
   - Update dependencies
   - Review security patches

## 📞 Support & Resources

- **Documentation**: README.md, DEPLOYMENT.md
- **Examples**: client_example.R
- **Tests**: tests.R
- **API Docs**: http://localhost:8000/docs

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**License**: MIT
