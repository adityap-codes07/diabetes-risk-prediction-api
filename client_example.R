# ==============================
# Example API Client
# client_example.R
# ==============================

# This script demonstrates how to consume the Diabetes Prediction API
# from R, Python, and curl

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
})

# API Configuration
API_BASE_URL <- "http://localhost:8000"

cat("=" %>% rep(70) %>% paste(collapse = ""), "\n")
cat("DIABETES PREDICTION API - CLIENT EXAMPLES\n")
cat("=" %>% rep(70) %>% paste(collapse = ""), "\n\n")

# ===== R CLIENT EXAMPLE =====

#' Make a prediction using the API (R)
#'
#' @param patient_data List of patient features
#' @return Prediction result
predict_diabetes_api <- function(patient_data) {
  url <- paste0(API_BASE_URL, "/predict")
  
  response <- POST(
    url,
    body = patient_data,
    encode = "json",
    content_type_json()
  )
  
  if (status_code(response) == 200) {
    result <- content(response, as = "parsed")
    return(result$data)
  } else {
    stop(sprintf("API Error: %s", content(response, as = "text")))
  }
}

#' Batch prediction using the API (R)
#'
#' @param patients_df Data frame of patient records
#' @return List of predictions
predict_batch_api <- function(patients_df) {
  url <- paste0(API_BASE_URL, "/predict/batch")
  
  # Convert data frame to list of records
  patients_list <- lapply(1:nrow(patients_df), function(i) {
    as.list(patients_df[i, ])
  })
  
  response <- POST(
    url,
    body = toJSON(patients_list, auto_unbox = TRUE),
    content_type_json()
  )
  
  if (status_code(response) == 200) {
    result <- content(response, as = "parsed")
    return(result$data)
  } else {
    stop(sprintf("API Error: %s", content(response, as = "text")))
  }
}

# Example usage
cat("\n===== R CLIENT EXAMPLE =====\n\n")

# Check API health
tryCatch({
  health_response <- GET(paste0(API_BASE_URL, "/health"))
  if (status_code(health_response) == 200) {
    cat("✓ API is healthy and running\n\n")
  }
}, error = function(e) {
  cat("✗ Cannot connect to API. Make sure it's running with: Rscript run_api.R\n\n")
  cat("Error:", e$message, "\n\n")
})

# Single prediction example
patient1 <- list(
  Age = 50,
  BMI = 32.5,
  BloodSugar = 148,
  insulin = 125,
  pressure = 88,
  pregnant = 2
)

tryCatch({
  cat("Making single prediction...\n")
  result <- predict_diabetes_api(patient1)
  
  cat("\nPatient Profile:\n")
  cat(sprintf("  Age: %d years\n", patient1$Age))
  cat(sprintf("  BMI: %.1f kg/m²\n", patient1$BMI))
  cat(sprintf("  Blood Sugar: %d mg/dL\n", patient1$BloodSugar))
  
  cat("\nPrediction Results:\n")
  cat(sprintf("  Prediction: %s\n", result$prediction))
  cat(sprintf("  Probability: %.1f%%\n", result$probability * 100))
  cat(sprintf("  Risk Category: %s\n", result$risk_category))
  cat(sprintf("  Confidence: %.1f%%\n", result$confidence * 100))
  
}, error = function(e) {
  cat("Error:", e$message, "\n")
})

cat("\n")

# Batch prediction example
patients_df <- data.frame(
  Age = c(50, 35, 60),
  BMI = c(32.5, 28.0, 35.2),
  BloodSugar = c(148, 110, 165),
  insulin = c(125, 80, 150),
  pressure = c(88, 75, 95),
  pregnant = c(2, 1, 3)
)

tryCatch({
  cat("Making batch prediction for 3 patients...\n\n")
  results <- predict_batch_api(patients_df)
  
  for (i in seq_along(results)) {
    cat(sprintf("Patient %d: %s risk (%.1f%% probability)\n", 
                i, 
                results[[i]]$risk_category,
                results[[i]]$probability * 100))
  }
  
}, error = function(e) {
  cat("Error:", e$message, "\n")
})

# ===== PYTHON CLIENT EXAMPLE =====
cat("\n\n===== PYTHON CLIENT EXAMPLE =====\n\n")

python_example <- '
import requests
import json

API_BASE_URL = "http://localhost:8000"

def predict_diabetes(patient_data):
    """Make a prediction using the API (Python)"""
    url = f"{API_BASE_URL}/predict"
    response = requests.post(url, json=patient_data)
    
    if response.status_code == 200:
        return response.json()["data"]
    else:
        raise Exception(f"API Error: {response.text}")

# Example usage
patient = {
    "Age": 50,
    "BMI": 32.5,
    "BloodSugar": 148,
    "insulin": 125,
    "pressure": 88,
    "pregnant": 2
}

try:
    result = predict_diabetes(patient)
    print(f"Prediction: {result[\'prediction\']}")
    print(f"Probability: {result[\'probability\']:.1%}")
    print(f"Risk Category: {result[\'risk_category\']}")
except Exception as e:
    print(f"Error: {e}")

# Batch prediction
patients = [
    {"Age": 50, "BMI": 32.5, "BloodSugar": 148, "insulin": 125, "pressure": 88, "pregnant": 2},
    {"Age": 35, "BMI": 28.0, "BloodSugar": 110, "insulin": 80, "pressure": 75, "pregnant": 1}
]

response = requests.post(f"{API_BASE_URL}/predict/batch", json=patients)
if response.status_code == 200:
    results = response.json()["data"]
    for i, result in enumerate(results, 1):
        print(f"Patient {i}: {result[\'risk_category\']} risk")
'

cat(python_example)

# ===== CURL EXAMPLES =====
cat("\n\n===== CURL EXAMPLES =====\n\n")

curl_examples <- '
# Health check
curl http://localhost:8000/health

# Get model information
curl http://localhost:8000/model/info

# Single prediction
curl -X POST http://localhost:8000/predict \\
  -H "Content-Type: application/json" \\
  -d \'{
    "Age": 50,
    "BMI": 32.5,
    "BloodSugar": 148,
    "insulin": 125,
    "pressure": 88,
    "pregnant": 2
  }\'

# Batch prediction
curl -X POST http://localhost:8000/predict/batch \\
  -H "Content-Type: application/json" \\
  -d \'[
    {"Age": 50, "BMI": 32.5, "BloodSugar": 148, "insulin": 125, "pressure": 88, "pregnant": 2},
    {"Age": 35, "BMI": 28.0, "BloodSugar": 110, "insulin": 80, "pressure": 75, "pregnant": 1}
  ]\'

# Predict blood sugar
curl -X POST http://localhost:8000/predict/bloodsugar \\
  -H "Content-Type: application/json" \\
  -d \'{
    "Age": 45,
    "BMI": 30.0,
    "insulin": 100,
    "pressure": 80,
    "pregnant": 1
  }\'
'

cat(curl_examples)

cat("\n\n")
cat("=" %>% rep(70) %>% paste(collapse = ""), "\n")
cat("For more examples, visit: http://localhost:8000/docs\n")
cat("=" %>% rep(70) %>% paste(collapse = ""), "\n")
