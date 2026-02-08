# ==============================
# Utility Functions Module
# utils.R
# ==============================

library(yaml)
library(logger)

#' Initialize Logger
#'
#' @param config Configuration list
#' @return NULL
initialize_logger <- function(config) {
  log_dir <- config$output$logs_dir
  if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE)
  
  log_file <- file.path(log_dir, config$logging$file)
  
  # Set log level
  log_level <- switch(config$logging$level,
                      "DEBUG" = logger::DEBUG,
                      "INFO" = logger::INFO,
                      "WARNING" = logger::WARN,
                      "ERROR" = logger::ERROR,
                      logger::INFO)
  
  logger::log_threshold(log_level)
  logger::log_appender(logger::appender_tee(log_file))
  logger::log_formatter(logger::formatter_glue)
  
  logger::log_info("Logger initialized successfully")
}

#' Load Configuration
#'
#' @param config_path Path to YAML config file
#' @return Configuration list
load_config <- function(config_path = "config.yaml") {
  tryCatch({
    config <- yaml::read_yaml(config_path)
    logger::log_info("Configuration loaded from {config_path}")
    return(config)
  }, error = function(e) {
    stop(sprintf("Failed to load configuration: %s", e$message))
  })
}

#' Create Output Directories
#'
#' @param config Configuration list
#' @return NULL
create_output_dirs <- function(config) {
  dirs <- c(
    config$output$results_dir,
    config$output$models_dir,
    config$output$logs_dir,
    config$output$plots_dir,
    config$output$reports_dir
  )
  
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      logger::log_info("Created directory: {dir}")
    }
  }
}

#' Safe Data Loading with Validation
#'
#' @param min_rows Minimum required rows
#' @return Data frame
load_and_validate_data <- function(min_rows = 100) {
  tryCatch({
    logger::log_info("Loading PimaIndiansDiabetes2 dataset")
    data("PimaIndiansDiabetes2", package = "mlbench", envir = environment())
    df <- get("PimaIndiansDiabetes2", envir = environment())
    
    # Validate data
    if (nrow(df) < min_rows) {
      stop(sprintf("Dataset has %d rows, minimum required: %d", nrow(df), min_rows))
    }
    
    logger::log_info("Dataset loaded: {nrow(df)} rows, {ncol(df)} columns")
    return(df)
    
  }, error = function(e) {
    logger::log_error("Data loading failed: {e$message}")
    stop(e$message)
  })
}

#' Handle Missing Values with Multiple Strategies
#'
#' @param df Data frame
#' @param threshold Column missing threshold (0-1)
#' @param strategy Strategy: "remove", "impute_mean", "impute_median"
#' @return Cleaned data frame
handle_missing_values <- function(df, threshold = 0.3, strategy = "remove") {
  original_rows <- nrow(df)
  original_cols <- ncol(df)
  
  # Calculate missing percentage per column
  missing_pct <- colMeans(is.na(df))
  cols_to_drop <- names(missing_pct[missing_pct > threshold])
  
  if (length(cols_to_drop) > 0) {
    logger::log_warn("Dropping columns with >{threshold*100}% missing: {paste(cols_to_drop, collapse=', ')}")
    df <- df[, !names(df) %in% cols_to_drop]
  }
  
  # Handle remaining missing values
  if (strategy == "remove") {
    df <- na.omit(df)
    logger::log_info("Removed {original_rows - nrow(df)} rows with missing values")
  } else if (strategy == "impute_mean") {
    numeric_cols <- names(df)[sapply(df, is.numeric)]
    for (col in numeric_cols) {
      if (any(is.na(df[[col]]))) {
        df[[col]][is.na(df[[col]])] <- mean(df[[col]], na.rm = TRUE)
      }
    }
    logger::log_info("Imputed missing values using mean")
  } else if (strategy == "impute_median") {
    numeric_cols <- names(df)[sapply(df, is.numeric)]
    for (col in numeric_cols) {
      if (any(is.na(df[[col]]))) {
        df[[col]][is.na(df[[col]])] <- median(df[[col]], na.rm = TRUE)
      }
    }
    logger::log_info("Imputed missing values using median")
  }
  
  logger::log_info("Data after cleaning: {nrow(df)} rows, {ncol(df)} columns")
  return(df)
}

#' Detect and Handle Outliers
#'
#' @param df Data frame
#' @param columns Columns to check for outliers
#' @param method Method: "IQR", "zscore"
#' @param threshold Threshold value
#' @return Data frame with outlier information
detect_outliers <- function(df, columns, method = "IQR", threshold = 3.0) {
  outlier_info <- list()
  
  for (col in columns) {
    if (!col %in% names(df) || !is.numeric(df[[col]])) next
    
    if (method == "IQR") {
      Q1 <- quantile(df[[col]], 0.25, na.rm = TRUE)
      Q3 <- quantile(df[[col]], 0.75, na.rm = TRUE)
      IQR <- Q3 - Q1
      lower_bound <- Q1 - threshold * IQR
      upper_bound <- Q3 + threshold * IQR
      outliers <- df[[col]] < lower_bound | df[[col]] > upper_bound
    } else if (method == "zscore") {
      z_scores <- abs(scale(df[[col]]))
      outliers <- z_scores > threshold
    }
    
    n_outliers <- sum(outliers, na.rm = TRUE)
    if (n_outliers > 0) {
      outlier_info[[col]] <- list(
        count = n_outliers,
        percentage = (n_outliers / nrow(df)) * 100
      )
      logger::log_warn("{col}: {n_outliers} outliers detected ({round(outlier_info[[col]]$percentage, 2)}%)")
    }
  }
  
  attr(df, "outlier_info") <- outlier_info
  return(df)
}

#' Split Data into Train/Validation/Test
#'
#' @param df Data frame
#' @param test_size Test set proportion
#' @param validation_size Validation set proportion
#' @param seed Random seed
#' @return List with train, validation, test sets
split_data <- function(df, test_size = 0.2, validation_size = 0.2, seed = 42) {
  set.seed(seed)
  
  n <- nrow(df)
  n_test <- floor(n * test_size)
  n_val <- floor(n * validation_size)
  n_train <- n - n_test - n_val
  
  indices <- sample(1:n)
  train_idx <- indices[1:n_train]
  val_idx <- indices[(n_train + 1):(n_train + n_val)]
  test_idx <- indices[(n_train + n_val + 1):n]
  
  logger::log_info("Data split - Train: {n_train}, Validation: {n_val}, Test: {n_test}")
  
  return(list(
    train = df[train_idx, ],
    validation = df[val_idx, ],
    test = df[test_idx, ]
  ))
}

#' Calculate Model Metrics
#'
#' @param actual Actual values
#' @param predicted Predicted probabilities
#' @param threshold Classification threshold
#' @return List of metrics
calculate_metrics <- function(actual, predicted, threshold = 0.5) {
  predicted_class <- ifelse(predicted >= threshold, levels(actual)[2], levels(actual)[1])
  predicted_class <- factor(predicted_class, levels = levels(actual))
  
  # Confusion matrix
  cm <- table(Actual = actual, Predicted = predicted_class)
  
  TP <- cm[2, 2]
  TN <- cm[1, 1]
  FP <- cm[1, 2]
  FN <- cm[2, 1]
  
  metrics <- list(
    accuracy = (TP + TN) / sum(cm),
    sensitivity = TP / (TP + FN),  # Recall, TPR
    specificity = TN / (TN + FP),
    precision = TP / (TP + FP),
    f1_score = 2 * (TP / (TP + FP)) * (TP / (TP + FN)) / ((TP / (TP + FP)) + (TP / (TP + FN))),
    confusion_matrix = cm
  )
  
  return(metrics)
}

#' Save Model Artifacts
#'
#' @param model Model object
#' @param model_name Model name
#' @param output_dir Output directory
#' @return Path to saved model
save_model <- function(model, model_name, output_dir) {
  filepath <- file.path(output_dir, paste0(model_name, ".rds"))
  saveRDS(model, filepath)
  logger::log_info("Model saved: {filepath}")
  return(filepath)
}

#' Load Model from File
#'
#' @param filepath Path to model file
#' @return Model object
load_model <- function(filepath) {
  if (!file.exists(filepath)) {
    stop(sprintf("Model file not found: %s", filepath))
  }
  model <- readRDS(filepath)
  logger::log_info("Model loaded: {filepath}")
  return(model)
}

#' Generate Model Report
#'
#' @param model_info List containing model information
#' @param output_path Path to save report
#' @return NULL
generate_report <- function(model_info, output_path) {
  report <- c(
    "=" %>% rep(70) %>% paste(collapse = ""),
    "DIABETES RISK PREDICTION MODEL - EVALUATION REPORT",
    "=" %>% rep(70) %>% paste(collapse = ""),
    "",
    sprintf("Model Version: %s", model_info$version),
    sprintf("Generated: %s", Sys.time()),
    "",
    "--- PERFORMANCE METRICS ---",
    sprintf("AUC-ROC: %.4f", model_info$auc),
    sprintf("Accuracy: %.4f", model_info$metrics$accuracy),
    sprintf("Sensitivity: %.4f", model_info$metrics$sensitivity),
    sprintf("Specificity: %.4f", model_info$metrics$specificity),
    sprintf("Precision: %.4f", model_info$metrics$precision),
    sprintf("F1 Score: %.4f", model_info$metrics$f1_score),
    "",
    "--- CONFUSION MATRIX ---",
    capture.output(print(model_info$metrics$confusion_matrix)),
    "",
    "=" %>% rep(70) %>% paste(collapse = "")
  )
  
  writeLines(report, output_path)
  logger::log_info("Report saved: {output_path}")
}
