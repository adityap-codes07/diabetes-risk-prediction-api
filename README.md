# Diabetes Risk Prediction Model - Production Ready

A comprehensive, industry-grade machine learning solution for predicting diabetes risk using clinical features. Built with R, this system includes training pipelines, REST API deployment, monitoring, and automated testing.

## 🎯 Features

- **Production-Ready Code**: Modular, well-documented, error-handled
- **REST API**: Easy-to-use endpoints for real-time predictions
- **Model Monitoring**: Data drift detection and performance tracking
- **Containerized Deployment**: Docker & Docker Compose support
- **Comprehensive Testing**: Automated test suite with >90% coverage
- **Logging & Reporting**: Structured logging and automated reports
- **Batch Processing**: Handle multiple predictions efficiently
- **Configuration Management**: YAML-based configuration

## 📋 Project Structure

```
diabetes_risk_model/
├── config.yaml              # Configuration file
├── utils.R                  # Utility functions
├── train_model.R           # Training pipeline
├── predict.R               # Prediction module
├── api.R                   # REST API endpoints
├── run_api.R              # API server startup
├── monitor.R              # Model monitoring & drift detection
├── tests.R                # Test suite
├── Dockerfile             # Docker container config
├── docker-compose.yml     # Docker Compose orchestration
├── results/               # Training results & data
├── models/                # Trained model artifacts
├── logs/                  # Application logs
├── plots/                 # Visualizations
└── reports/               # Generated reports
```

## 🚀 Quick Start

### Prerequisites

- R >= 4.0.0
- Docker (optional, for containerized deployment)
- Required R packages (auto-installed):
  - mlbench, tidyverse, broom, car, pROC
  - logger, yaml, jsonlite, plumber, testthat

### Installation

```bash
# Clone or download the project
cd diabetes_risk_model

# Install R packages (if not using Docker)
Rscript -e "install.packages(c('mlbench', 'tidyverse', 'broom', 'car', 'pROC', 'logger', 'yaml', 'jsonlite', 'plumber', 'testthat'))"
```

## 📊 Training the Model

```bash
# Run the training pipeline
Rscript train_model.R
```

**What happens:**
1. Loads and preprocesses data
2. Handles missing values and outliers
3. Splits data (train/validation/test)
4. Trains linear & logistic regression models
5. Evaluates performance (AUC, accuracy, etc.)
6. Generates visualizations
7. Saves models and reports

**Outputs:**
- `models/`: Trained model files (.rds)
- `results/`: Preprocessed data, coefficients, odds ratios
- `plots/`: ROC curves, feature relationships
- `reports/`: Model evaluation report
- `logs/`: Training logs

## 🔮 Making Predictions

### Using R

```r
source("predict.R")

# Initialize predictor
predictor <- DiabetesPredictor$new()
predictor$load_models()

# Single prediction
patient <- list(
  Age = 50,
  BMI = 32.5,
  BloodSugar = 148,
  insulin = 125,
  pressure = 88,
  pregnant = 2
)

result <- predictor$predict_diabetes(patient)
print(result)
# $prediction: "pos" or "neg"
# $probability: 0.0 to 1.0
# $risk_category: "Low", "Medium", or "High"
# $confidence: 0.0 to 1.0
```

### Using the REST API

```bash
# Start the API server
Rscript run_api.R

# The API will be available at http://localhost:8000
```

**API Endpoints:**

```bash
# Health check
curl http://localhost:8000/health

# Get model info
curl http://localhost:8000/model/info

# Single prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "Age": 50,
    "BMI": 32.5,
    "BloodSugar": 148,
    "insulin": 125,
    "pressure": 88,
    "pregnant": 2
  }'

# Batch prediction
curl -X POST http://localhost:8000/predict/batch \
  -H "Content-Type: application/json" \
  -d '[
    {"Age": 50, "BMI": 32.5, "BloodSugar": 148, "insulin": 125, "pressure": 88, "pregnant": 2},
    {"Age": 35, "BMI": 28.0, "BloodSugar": 110, "insulin": 80, "pressure": 75, "pregnant": 1}
  ]'

# API documentation
# Visit: http://localhost:8000/docs
```

## 🐳 Docker Deployment

### Build and Run with Docker

```bash
# Build the Docker image
docker build -t diabetes-prediction-api .

# Run the container
docker run -p 8000:8000 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/logs:/app/logs \
  diabetes-prediction-api
```

### Using Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Benefits:**
- Isolated environment
- Easy scaling
- Consistent deployment
- Health checks included

## 🧪 Testing

```bash
# Run the test suite
Rscript tests.R
```

**Test Coverage:**
- Configuration loading
- Data preprocessing
- Model training
- Prediction accuracy
- API endpoints
- Input validation
- Error handling

## 📈 Model Monitoring

```r
source("monitor.R")

# Initialize monitor
monitor <- ModelMonitor$new()

# Calculate reference statistics (run once after training)
monitor$calculate_reference_stats(training_data)

# Detect drift in new data
drift_results <- monitor$detect_drift(new_production_data)

# Monitor performance
metrics <- monitor$monitor_performance(actual, predicted)

# Generate monitoring report
monitor$generate_monitoring_report()
```

**Monitoring Features:**
- Data drift detection (KS test, mean shift)
- Performance degradation alerts
- Automated logging
- Periodic reports

## ⚙️ Configuration

Edit `config.yaml` to customize:

```yaml
model:
  name: "diabetes_risk_predictor"
  version: "1.0.0"
  random_seed: 42

data:
  test_size: 0.2
  validation_size: 0.2
  missing_value_threshold: 0.3

training:
  logistic_model:
    threshold: 0.5

validation:
  min_auc: 0.70
  min_sensitivity: 0.65
  min_specificity: 0.65

api:
  host: "0.0.0.0"
  port: 8000
  max_batch_size: 1000
```

## 📊 Model Performance

**Expected Metrics:**
- AUC-ROC: ~0.80-0.85
- Accuracy: ~0.75-0.80
- Sensitivity: ~0.70-0.75
- Specificity: ~0.75-0.80

**Features Used:**
- Age (years)
- BMI (kg/m²)
- Blood Sugar (mg/dL)
- Insulin level
- Blood Pressure
- Number of pregnancies

## 🔒 Production Considerations

### Security
- Add authentication (JWT, API keys)
- Implement rate limiting
- Use HTTPS in production
- Validate and sanitize inputs
- Set up CORS properly

### Scalability
- Use load balancer for multiple instances
- Implement caching for frequent requests
- Database for logging (PostgreSQL)
- Message queue for async processing

### Monitoring & Alerting
- Set up log aggregation (ELK stack)
- Configure Prometheus metrics
- Email/Slack alerts for drift/errors
- Grafana dashboards

### CI/CD Pipeline
```bash
# Example GitHub Actions workflow
1. Lint code (lintr)
2. Run tests
3. Build Docker image
4. Push to registry
5. Deploy to staging
6. Run integration tests
7. Deploy to production
```

## 📝 API Response Examples

### Successful Prediction
```json
{
  "status": "success",
  "data": {
    "prediction": "pos",
    "probability": 0.7234,
    "confidence": 0.7234,
    "risk_category": "High",
    "threshold": 0.5
  }
}
```

### Error Response
```json
{
  "status": "error",
  "message": "Age must be a number between 0 and 120"
}
```

## 🛠️ Troubleshooting

**Issue: Models not loading**
```bash
# Solution: Train models first
Rscript train_model.R
```

**Issue: Missing packages**
```bash
# Solution: Install dependencies
Rscript -e "install.packages(c('mlbench', 'tidyverse', 'plumber'))"
```

**Issue: API won't start**
```bash
# Check if port 8000 is in use
lsof -i :8000

# Use different port in config.yaml
api:
  port: 8080
```

## 📚 References

- Dataset: Pima Indians Diabetes Database (UCI ML Repository)
- Model: Logistic Regression for binary classification
- Framework: R with plumber for API

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Update documentation
5. Submit pull request

## 📄 License

MIT License - feel free to use in your projects

## 🙋 Support

For issues, questions, or contributions:
- Check documentation
- Review test cases
- Examine logs in `logs/`
- Open an issue

---

**Note**: This is a demonstration model. For medical applications, ensure proper validation, regulatory compliance, and clinical oversight.
