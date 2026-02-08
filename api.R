# ==============================
# REST API using Plumber
# api.R
# ==============================

library(plumber)
library(jsonlite)
library(logger)

source("predict.R")

# Initialize predictor globally
predictor <- NULL

#' @apiTitle Diabetes Risk Prediction API
#' @apiDescription REST API for predicting diabetes risk using machine learning models
#' @apiVersion 1.0.0

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

#* Health check endpoint
#* @get /health
#* @serializer json
function() {
  list(
    status = "healthy",
    timestamp = Sys.time(),
    service = "diabetes-prediction-api",
    version = "1.0.0"
  )
}

#* Get model information
#* @get /model/info
#* @serializer json
function(res) {
  tryCatch({
    if (is.null(predictor)) {
      res$status <- 503
      return(list(error = "Model not loaded"))
    }
    
    info <- predictor$get_model_info()
    return(list(
      status = "success",
      data = info
    ))
    
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = e$message
    ))
  })
}

#* Predict diabetes risk for a single patient
#* @post /predict
#* @param Age:numeric Patient age in years
#* @param BMI:numeric Body Mass Index
#* @param BloodSugar:numeric Blood glucose level (mg/dL)
#* @param insulin:numeric Insulin level
#* @param pressure:numeric Blood pressure
#* @param pregnant:numeric Number of pregnancies
#* @serializer json
function(req, res, Age, BMI, BloodSugar, insulin, pressure, pregnant) {
  tryCatch({
    if (is.null(predictor)) {
      res$status <- 503
      return(list(
        status = "error",
        message = "Model not loaded"
      ))
    }
    
    # Parse input
    input_data <- list(
      Age = as.numeric(Age),
      BMI = as.numeric(BMI),
      BloodSugar = as.numeric(BloodSugar),
      insulin = as.numeric(insulin),
      pressure = as.numeric(pressure),
      pregnant = as.numeric(pregnant)
    )
    
    # Make prediction
    result <- predictor$predict_diabetes(input_data)
    
    return(list(
      status = "success",
      data = result
    ))
    
  }, error = function(e) {
    res$status <- 400
    return(list(
      status = "error",
      message = e$message
    ))
  })
}

#* Predict diabetes risk for multiple patients
#* @post /predict/batch
#* @serializer json
function(req, res) {
  tryCatch({
    if (is.null(predictor)) {
      res$status <- 503
      return(list(
        status = "error",
        message = "Model not loaded"
      ))
    }
    
    # Parse JSON body
    body <- jsonlite::fromJSON(req$postBody)
    
    # Validate it's a list or data frame
    if (!is.list(body) && !is.data.frame(body)) {
      res$status <- 400
      return(list(
        status = "error",
        message = "Request body must be a JSON array of patient records"
      ))
    }
    
    # Convert to data frame if needed
    if (is.list(body) && !is.data.frame(body)) {
      input_df <- as.data.frame(do.call(rbind, lapply(body, as.data.frame)))
    } else {
      input_df <- as.data.frame(body)
    }
    
    # Make batch prediction
    results <- predictor$predict_batch(input_df)
    
    return(list(
      status = "success",
      count = length(results),
      data = results
    ))
    
  }, error = function(e) {
    res$status <- 400
    return(list(
      status = "error",
      message = e$message
    ))
  })
}

#* Predict blood sugar level
#* @post /predict/bloodsugar
#* @param Age:numeric Patient age in years
#* @param BMI:numeric Body Mass Index
#* @param insulin:numeric Insulin level
#* @param pressure:numeric Blood pressure
#* @param pregnant:numeric Number of pregnancies
#* @serializer json
function(req, res, Age, BMI, insulin, pressure, pregnant) {
  tryCatch({
    if (is.null(predictor)) {
      res$status <- 503
      return(list(
        status = "error",
        message = "Model not loaded"
      ))
    }
    
    input_data <- list(
      Age = as.numeric(Age),
      BMI = as.numeric(BMI),
      insulin = as.numeric(insulin),
      pressure = as.numeric(pressure),
      pregnant = as.numeric(pregnant)
    )
    
    result <- predictor$predict_blood_sugar(input_data)
    
    return(list(
      status = "success",
      data = result
    ))
    
  }, error = function(e) {
    res$status <- 400
    return(list(
      status = "error",
      message = e$message
    ))
  })
}

#* Get API documentation
#* @get /docs
#* @html
function() {
  "
  <html>
  <head>
    <title>Diabetes Prediction API Documentation</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
      h1 { color: #2c3e50; }
      h2 { color: #34495e; margin-top: 30px; }
      code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
      pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
      .endpoint { background: #e8f4f8; padding: 10px; margin: 10px 0; border-left: 4px solid #3498db; }
    </style>
  </head>
  <body>
    <h1>Diabetes Risk Prediction API</h1>
    <p>REST API for predicting diabetes risk using machine learning models</p>
    
    <h2>Endpoints</h2>
    
    <div class='endpoint'>
      <h3>GET /health</h3>
      <p>Health check endpoint</p>
    </div>
    
    <div class='endpoint'>
      <h3>GET /model/info</h3>
      <p>Get model version and performance metrics</p>
    </div>
    
    <div class='endpoint'>
      <h3>POST /predict</h3>
      <p>Predict diabetes risk for a single patient</p>
      <p><strong>Parameters:</strong></p>
      <ul>
        <li>Age: Patient age (numeric)</li>
        <li>BMI: Body Mass Index (numeric)</li>
        <li>BloodSugar: Blood glucose level in mg/dL (numeric)</li>
        <li>insulin: Insulin level (numeric)</li>
        <li>pressure: Blood pressure (numeric)</li>
        <li>pregnant: Number of pregnancies (numeric)</li>
      </ul>
      <pre>
curl -X POST 'http://localhost:8000/predict' \\
  -H 'Content-Type: application/json' \\
  -d '{
    \"Age\": 50,
    \"BMI\": 32.5,
    \"BloodSugar\": 148,
    \"insulin\": 125,
    \"pressure\": 88,
    \"pregnant\": 2
  }'
      </pre>
    </div>
    
    <div class='endpoint'>
      <h3>POST /predict/batch</h3>
      <p>Predict diabetes risk for multiple patients</p>
      <pre>
curl -X POST 'http://localhost:8000/predict/batch' \\
  -H 'Content-Type: application/json' \\
  -d '[
    {\"Age\": 50, \"BMI\": 32.5, \"BloodSugar\": 148, \"insulin\": 125, \"pressure\": 88, \"pregnant\": 2},
    {\"Age\": 35, \"BMI\": 28.0, \"BloodSugar\": 110, \"insulin\": 80, \"pressure\": 75, \"pregnant\": 1}
  ]'
      </pre>
    </div>
    
    <div class='endpoint'>
      <h3>POST /predict/bloodsugar</h3>
      <p>Predict blood sugar level based on patient features</p>
    </div>
    
  </body>
  </html>
  "
}
