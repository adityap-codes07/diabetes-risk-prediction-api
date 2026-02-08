# ==============================
# Testing Suite
# tests.R
# ==============================

suppressPackageStartupMessages({
  library(testthat)
  library(mlbench)
})

source("utils.R")
source("predict.R")

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("RUNNING TEST SUITE\n")
cat(paste(rep("=", 70), collapse = ""), "\n")


# ===== Test Configuration Loading =====
test_that("Configuration loading works", {
  config <- load_config("config.yaml")
  expect_true(is.list(config))
  expect_true("model" %in% names(config))
  expect_true("data" %in% names(config))
  expect_true("training" %in% names(config))
})

# ===== Test Data Loading =====
test_that("Data loading and validation works", {
  df <- load_and_validate_data(min_rows = 100)
  expect_true(is.data.frame(df))
  expect_true(nrow(df) >= 100)
  expect_true("diabetes" %in% names(df))
})

# ===== Test Missing Value Handling =====
test_that("Missing value handling works", {
  data("PimaIndiansDiabetes2", package = "mlbench")
  df <- PimaIndiansDiabetes2
  
  # Test removal strategy
  df_clean <- handle_missing_values(df, threshold = 0.5, strategy = "remove")
  expect_true(is.data.frame(df_clean))
  expect_true(nrow(df_clean) <= nrow(df))
  expect_true(sum(is.na(df_clean)) == 0)
})

# ===== Test Data Splitting =====
test_that("Data splitting works correctly", {
  data("PimaIndiansDiabetes2", package = "mlbench")
  df <- na.omit(PimaIndiansDiabetes2)
  
  splits <- split_data(df, test_size = 0.2, validation_size = 0.2, seed = 42)
  
  expect_true(is.list(splits))
  expect_true(all(c("train", "validation", "test") %in% names(splits)))
  
  total_rows <- nrow(splits$train) + nrow(splits$validation) + nrow(splits$test)
  expect_equal(total_rows, nrow(df))
  
  # Check proportions (with tolerance)
  expect_true(abs(nrow(splits$test) / nrow(df) - 0.2) < 0.05)
  expect_true(abs(nrow(splits$validation) / nrow(df) - 0.2) < 0.05)
})

# ===== Test Metrics Calculation =====
test_that("Metrics calculation works", {
  actual <- factor(c("neg", "pos", "neg", "pos", "neg", "pos", "neg", "pos"),
                   levels = c("neg", "pos"))
  predicted <- c(0.2, 0.8, 0.3, 0.7, 0.1, 0.9, 0.4, 0.6)
  
  metrics <- calculate_metrics(actual, predicted, threshold = 0.5)
  
  expect_true(is.list(metrics))
  expect_true(all(c("accuracy", "sensitivity", "specificity", "precision", "f1_score") %in% names(metrics)))
  expect_true(metrics$accuracy >= 0 && metrics$accuracy <= 1)
  expect_true(metrics$sensitivity >= 0 && metrics$sensitivity <= 1)
  expect_true(metrics$specificity >= 0 && metrics$specificity <= 1)
})

# ===== Test Outlier Detection =====
test_that("Outlier detection works", {
  df <- data.frame(
    x = c(1, 2, 3, 4, 5, 100),  # 100 is an outlier
    y = c(10, 12, 11, 13, 12, 14)
  )
  
  result <- detect_outliers(df, columns = c("x"), method = "IQR", threshold = 1.5)
  outlier_info <- attr(result, "outlier_info")
  
  expect_true(is.list(outlier_info))
  expect_true("x" %in% names(outlier_info))
  expect_true(outlier_info$x$count > 0)
})

# ===== Test Model Saving and Loading =====
test_that("Model saving and loading works", {
  # Create temporary directory
  temp_dir <- tempdir()
  
  # Train simple model
  data("PimaIndiansDiabetes2", package = "mlbench")
  df <- na.omit(PimaIndiansDiabetes2)
  model <- lm(glucose ~ age + mass, data = df)
  
  # Save model
  model_path <- save_model(model, "test_model", temp_dir)
  expect_true(file.exists(model_path))
  
  # Load model
  loaded_model <- load_model(model_path)
  expect_true(!is.null(loaded_model))
  expect_equal(class(model), class(loaded_model))
  
  # Cleanup
  unlink(model_path)
})

# ===== Test Predictor Class =====
test_that("DiabetesPredictor initialization works", {
  predictor <- DiabetesPredictor$new("config.yaml")
  expect_true(!is.null(predictor))
  expect_true(is.list(predictor$config))
  expect_false(predictor$is_loaded)
})

# ===== Test Input Validation =====
test_that("Input validation catches invalid data", {
  predictor <- DiabetesPredictor$new("config.yaml")
  
  # Valid data
  valid_data <- list(
    Age = 50,
    BMI = 32.5,
    BloodSugar = 148,
    insulin = 125,
    pressure = 88,
    pregnant = 2
  )
  expect_true(predictor$validate_input(valid_data))
  
  # Invalid age
  invalid_age <- valid_data
  invalid_age$Age <- -5
  expect_error(predictor$validate_input(invalid_age))
  
  # Invalid BMI
  invalid_bmi <- valid_data
  invalid_bmi$BMI <- 150
  expect_error(predictor$validate_input(invalid_bmi))
  
  # Missing field
  incomplete_data <- valid_data
  incomplete_data$Age <- NULL
  expect_error(predictor$validate_input(incomplete_data))
})

# ===== Integration Test =====
test_that("End-to-end prediction works if models exist", {
  skip_if_not(
    file.exists("models/logistic_model.rds"),
    "Models not trained yet - run train_model.R first"
  )
  
  predictor <- DiabetesPredictor$new("config.yaml")
  predictor$load_models()
  
  patient_data <- list(
    Age = 50,
    BMI = 32.5,
    BloodSugar = 148,
    insulin = 125,
    pressure = 88,
    pregnant = 2
  )
  
  result <- predictor$predict_diabetes(patient_data)
  
  expect_true(is.list(result))
  expect_true("prediction" %in% names(result))
  expect_true("probability" %in% names(result))
  expect_true("risk_category" %in% names(result))
  expect_true(result$probability >= 0 && result$probability <= 1)
  expect_true(result$risk_category %in% c("Low", "Medium", "High"))
})

cat("\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
cat("TEST SUITE COMPLETED\n")
cat(paste(rep("=", 70), collapse = ""), "\n")
