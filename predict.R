# ==============================
# Prediction API Module
# predict.R
# ==============================

suppressPackageStartupMessages({
  library(logger)
  library(yaml)
  library(jsonlite)
})

source("utils.R")

#' DiabetesPredictor Class
#'
#' Encapsulates model loading and prediction logic
DiabetesPredictor <- setRefClass(
  "DiabetesPredictor",
  
  fields = list(
    config = "list",
    logistic_model = "ANY",
    linear_model = "ANY",
    metadata = "list",
    is_loaded = "logical"
  ),
  
  methods = list(
    
    #' Initialize Predictor
    initialize = function(config_path = "config.yaml") {
      config <<- load_config(config_path)
      is_loaded <<- FALSE
      logger::log_info("DiabetesPredictor initialized")
    },
    
    #' Load Trained Models
    load_models = function() {
      tryCatch({
        # Load logistic model for diabetes prediction
        logistic_path <- file.path(
          config$output$models_dir,
          "logistic_model.rds"
        )
        logistic_model <<- load_model(logistic_path)
        
        # Load linear model for blood sugar prediction
        linear_path <- file.path(
          config$output$models_dir,
          "linear_model.rds"
        )
        linear_model <<- load_model(linear_path)
        
        # Load metadata
        metadata_path <- file.path(
          config$output$models_dir,
          "model_metadata.yaml"
        )
        if (file.exists(metadata_path)) {
          metadata <<- yaml::read_yaml(metadata_path)
        } else {
          metadata <<- list()
        }
        
        is_loaded <<- TRUE
        logger::log_info("Models loaded successfully")
        
      }, error = function(e) {
        logger::log_error("Failed to load models: {e$message}")
        stop(e$message)
      })
    },
    
    #' Validate Input Data
    validate_input = function(data) {
      required_fields <- c("Age", "BMI", "BloodSugar", "insulin", "pressure", "pregnant")
      
      # Check for missing fields
      missing_fields <- setdiff(required_fields, names(data))
      if (length(missing_fields) > 0) {
        stop(sprintf("Missing required fields: %s", paste(missing_fields, collapse = ", ")))
      }
      
      # Check data types and ranges
      if (!is.numeric(data$Age) || data$Age < 0 || data$Age > 120) {
        stop("Age must be a number between 0 and 120")
      }
      if (!is.numeric(data$BMI) || data$BMI < 10 || data$BMI > 80) {
        stop("BMI must be a number between 10 and 80")
      }
      if (!is.numeric(data$BloodSugar) || data$BloodSugar < 0 || data$BloodSugar > 500) {
        stop("BloodSugar must be a number between 0 and 500")
      }
      if (!is.numeric(data$insulin) || data$insulin < 0) {
        stop("Insulin must be a non-negative number")
      }
      if (!is.numeric(data$pressure) || data$pressure < 0 || data$pressure > 300) {
        stop("Pressure must be a number between 0 and 300")
      }
      if (!is.numeric(data$pregnant) || data$pregnant < 0) {
        stop("Pregnant must be a non-negative number")
      }
      
      logger::log_debug("Input validation passed")
      return(TRUE)
    },
    
    #' Predict Diabetes Risk
    predict_diabetes = function(input_data) {
      if (!is_loaded) {
        stop("Models not loaded. Call load_models() first.")
      }
      
      # Validate input
      validate_input(input_data)
      
      # Convert to data frame if necessary
      if (!is.data.frame(input_data)) {
        input_data <- as.data.frame(input_data)
      }
      
      # Get prediction
      prob <- predict(logistic_model, newdata = input_data, type = "response")
      threshold <- config$training$logistic_model$threshold
      prediction <- ifelse(prob >= threshold, "pos", "neg")
      
      # Calculate confidence
      confidence <- ifelse(prediction == "pos", prob, 1 - prob)
      
      # Risk category
      risk_category <- case_when(
        prob < 0.3 ~ "Low",
        prob < 0.6 ~ "Medium",
        TRUE ~ "High"
      )
      
      result <- list(
        prediction = prediction,
        probability = as.numeric(prob),
        confidence = as.numeric(confidence),
        risk_category = risk_category,
        threshold = threshold
      )
      
      logger::log_debug("Prediction completed - Risk: {risk_category}, Prob: {round(prob, 4)}")
      return(result)
    },
    
    #' Predict Blood Sugar
    predict_blood_sugar = function(input_data) {
      if (!is_loaded) {
        stop("Models not loaded. Call load_models() first.")
      }
      
      # Validate required fields for linear model
      required_fields <- c("Age", "BMI", "insulin", "pressure", "pregnant")
      missing <- setdiff(required_fields, names(input_data))
      if (length(missing) > 0) {
        stop(sprintf("Missing fields for blood sugar prediction: %s", 
                     paste(missing, collapse = ", ")))
      }
      
      # Convert to data frame if necessary
      if (!is.data.frame(input_data)) {
        input_data <- as.data.frame(input_data)
      }
      
      # Get prediction
      predicted_value <- predict(linear_model, newdata = input_data)
      
      result <- list(
        predicted_blood_sugar = as.numeric(predicted_value)
      )
      
      logger::log_debug("Blood sugar prediction: {round(predicted_value, 2)}")
      return(result)
    },
    
    #' Batch Prediction
    predict_batch = function(input_df, max_batch_size = NULL) {
      if (is.null(max_batch_size)) {
        max_batch_size <- config$api$max_batch_size
      }
      
      if (nrow(input_df) > max_batch_size) {
        stop(sprintf("Batch size %d exceeds maximum %d", 
                     nrow(input_df), max_batch_size))
      }
      
      logger::log_info("Processing batch of {nrow(input_df)} samples")
      
      results <- vector("list", nrow(input_df))
      
      for (i in seq_len(nrow(input_df))) {
        tryCatch({
          results[[i]] <- predict_diabetes(input_df[i, ])
          results[[i]]$row_id <- i
        }, error = function(e) {
          results[[i]] <- list(
            row_id = i,
            error = e$message
          )
          logger::log_warn("Error in row {i}: {e$message}")
        })
      }
      
      return(results)
    },
    
    #' Get Model Information
    get_model_info = function() {
      return(list(
        version = metadata$model_version,
        training_date = metadata$training_date,
        test_auc = metadata$test_auc,
        test_accuracy = metadata$test_metrics$accuracy,
        features = metadata$features,
        validation_passed = metadata$validation_passed
      ))
    }
  )
)

#' Standalone Prediction Function
#'
#' @param input_data List or data frame with patient data
#' @param config_path Path to configuration file
#' @return Prediction result
predict_diabetes_risk <- function(input_data, config_path = "config.yaml") {
  predictor <- DiabetesPredictor$new(config_path)
  predictor$load_models()
  result <- predictor$predict_diabetes(input_data)
  return(result)
}

# Example usage for testing
if (!interactive()) {
  # Example patient data
  example_patient <- list(
    Age = 50,
    BMI = 32.5,
    BloodSugar = 148,
    insulin = 125,
    pressure = 88,
    pregnant = 2
  )
  
  # Make prediction
  predictor <- DiabetesPredictor$new()
  predictor$load_models()
  
  cat("\n===== DIABETES RISK PREDICTION =====\n")
  result <- predictor$predict_diabetes(example_patient)
  cat(sprintf("\nPatient Risk Assessment:\n"))
  cat(sprintf("  Prediction: %s\n", result$prediction))
  cat(sprintf("  Probability: %.2f%%\n", result$probability * 100))
  cat(sprintf("  Risk Category: %s\n", result$risk_category))
  cat(sprintf("  Confidence: %.2f%%\n", result$confidence * 100))
  
  cat("\n===== MODEL INFORMATION =====\n")
  info <- predictor$get_model_info()
  cat(sprintf("Model Version: %s\n", info$version))
  cat(sprintf("Training Date: %s\n", info$training_date))
  cat(sprintf("Test AUC: %.4f\n", info$test_auc))
  cat(sprintf("Test Accuracy: %.4f\n", info$test_accuracy))
}
