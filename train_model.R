# ==============================
# Main Training Pipeline
# train_model.R
# ==============================

# Suppress package startup messages
suppressPackageStartupMessages({
  library(mlbench)
  library(tidyverse)
  library(broom)
  library(car)
  library(pROC)
  library(logger)
  library(yaml)
})

source("utils.R")

#' Main Training Pipeline
#'
#' @param config_path Path to configuration file
#' @return List containing trained models and metrics
main <- function(config_path = "config.yaml") {
  
  # ===== INITIALIZATION =====
  config <- load_config(config_path)
  create_output_dirs(config)
  initialize_logger(config)
  
  logger::log_info("=" %>% rep(70) %>% paste(collapse = ""))
  logger::log_info("DIABETES RISK PREDICTION MODEL - TRAINING PIPELINE")
  logger::log_info("=" %>% rep(70) %>% paste(collapse = ""))
  
  set.seed(config$model$random_seed)
  
  # ===== DATA LOADING & PREPROCESSING =====
  logger::log_info("STEP 1: Data Loading and Preprocessing")
  
  df <- load_and_validate_data(config$data$min_required_rows)
  
  # Rename and select features
  df <- df %>%
    select(glucose, mass, age, pressure, pregnant, diabetes) %>%
    rename(
      BloodSugar = glucose,
      BMI        = mass,
      Age        = age,
      Diabetes   = diabetes
    )
  
  # Handle missing values
  df <- handle_missing_values(
    df, 
    threshold = config$data$missing_value_threshold,
    strategy = "remove"
  )
  
  # Detect outliers (log but don't remove in this version)
  numeric_cols <- c("BloodSugar", "BMI", "Age", "pressure")
  df <- detect_outliers(
    df, 
    columns = numeric_cols,
    method = config$data$outlier_method,
    threshold = config$data$outlier_threshold
  )
  
  # Save preprocessed data
  write.csv(df, 
            file.path(config$output$results_dir, "preprocessed_data.csv"),
            row.names = FALSE)
  logger::log_info("Preprocessed data saved")
  
  # ===== TRAIN/VALIDATION/TEST SPLIT =====
  logger::log_info("STEP 2: Data Splitting")
  
  data_splits <- split_data(
    df,
    test_size = config$data$test_size,
    validation_size = config$data$validation_size,
    seed = config$model$random_seed
  )
  
  train_data <- data_splits$train
  val_data <- data_splits$validation
  test_data <- data_splits$test
  
  # ===== LINEAR REGRESSION MODEL =====
  logger::log_info("STEP 3: Training Linear Regression Model")
  
  tryCatch({
    lm_formula <- as.formula(config$training$linear_model$formula)
    lm_model <- lm(lm_formula, data = train_data)
    
    # Model summary
    lm_summary <- summary(lm_model)
    logger::log_info("Linear Model R-squared: {round(lm_summary$r.squared, 4)}")
    logger::log_info("Linear Model Adj. R-squared: {round(lm_summary$adj.r.squared, 4)}")
    
    # Validation set performance
    val_predictions <- predict(lm_model, newdata = val_data)
    val_actual <- val_data$BloodSugar
    val_rmse <- sqrt(mean((val_actual - val_predictions)^2))
    val_mae <- mean(abs(val_actual - val_predictions))
    
    logger::log_info("Validation RMSE: {round(val_rmse, 4)}")
    logger::log_info("Validation MAE: {round(val_mae, 4)}")
    
    # Save model
    lm_model_path <- save_model(
      lm_model, 
      "linear_model", 
      config$output$models_dir
    )
    
    # Save coefficients
    lm_coef <- tidy(lm_model, conf.int = TRUE)
    write.csv(lm_coef, 
              file.path(config$output$results_dir, "linear_model_coefficients.csv"),
              row.names = FALSE)
    
  }, error = function(e) {
    logger::log_error("Linear model training failed: {e$message}")
    stop(e$message)
  })
  
  # ===== LOGISTIC REGRESSION MODEL =====
  logger::log_info("STEP 4: Training Logistic Regression Model")
  
  tryCatch({
    glm_formula <- as.formula(config$training$logistic_model$formula)
    glm_model <- glm(glm_formula, data = train_data, family = binomial)
    
    # Model summary
    glm_summary <- summary(glm_model)
    logger::log_info("Logistic Model AIC: {round(glm_summary$aic, 4)}")
    
    # Odds ratios
    or_table <- tidy(glm_model, conf.int = TRUE, exponentiate = TRUE) %>%
      select(term, estimate, conf.low, conf.high, p.value) %>%
      arrange(p.value)
    
    write.csv(or_table,
              file.path(config$output$results_dir, "odds_ratios.csv"),
              row.names = FALSE)
    logger::log_info("Odds ratios table saved")
    
    # Save model
    glm_model_path <- save_model(
      glm_model,
      "logistic_model",
      config$output$models_dir
    )
    
  }, error = function(e) {
    logger::log_error("Logistic model training failed: {e$message}")
    stop(e$message)
  })
  
  # ===== MODEL EVALUATION ON VALIDATION SET =====
  logger::log_info("STEP 5: Model Evaluation on Validation Set")
  
  # Predictions
  val_data$prob_diabetes <- predict(glm_model, newdata = val_data, type = "response")
  
  # ROC-AUC
  roc_obj <- roc(val_data$Diabetes, val_data$prob_diabetes, quiet = TRUE)
  auc_score <- as.numeric(auc(roc_obj))
  logger::log_info("Validation AUC: {round(auc_score, 4)}")
  
  # Calculate metrics
  metrics <- calculate_metrics(
    val_data$Diabetes,
    val_data$prob_diabetes,
    threshold = config$training$logistic_model$threshold
  )
  
  logger::log_info("Validation Accuracy: {round(metrics$accuracy, 4)}")
  logger::log_info("Validation Sensitivity: {round(metrics$sensitivity, 4)}")
  logger::log_info("Validation Specificity: {round(metrics$specificity, 4)}")
  logger::log_info("Validation Precision: {round(metrics$precision, 4)}")
  logger::log_info("Validation F1 Score: {round(metrics$f1_score, 4)}")
  
  # Validate against thresholds
  validation_passed <- TRUE
  if (auc_score < config$validation$min_auc) {
    logger::log_warn("AUC {round(auc_score, 4)} below threshold {config$validation$min_auc}")
    validation_passed <- FALSE
  }
  if (metrics$sensitivity < config$validation$min_sensitivity) {
    logger::log_warn("Sensitivity {round(metrics$sensitivity, 4)} below threshold {config$validation$min_sensitivity}")
    validation_passed <- FALSE
  }
  if (metrics$specificity < config$validation$min_specificity) {
    logger::log_warn("Specificity {round(metrics$specificity, 4)} below threshold {config$validation$min_specificity}")
    validation_passed <- FALSE
  }
  
  if (!validation_passed) {
    logger::log_error("Model failed validation checks!")
  } else {
    logger::log_info("✓ Model passed all validation checks")
  }
  
  # ===== TEST SET EVALUATION =====
  logger::log_info("STEP 6: Final Evaluation on Test Set")
  
  test_data$prob_diabetes <- predict(glm_model, newdata = test_data, type = "response")
  test_roc <- roc(test_data$Diabetes, test_data$prob_diabetes, quiet = TRUE)
  test_auc <- as.numeric(auc(test_roc))
  
  test_metrics <- calculate_metrics(
    test_data$Diabetes,
    test_data$prob_diabetes,
    threshold = config$training$logistic_model$threshold
  )
  
  logger::log_info("Test AUC: {round(test_auc, 4)}")
  logger::log_info("Test Accuracy: {round(test_metrics$accuracy, 4)}")
  logger::log_info("Test Sensitivity: {round(test_metrics$sensitivity, 4)}")
  logger::log_info("Test Specificity: {round(test_metrics$specificity, 4)}")
  
  # ===== VISUALIZATION =====
  logger::log_info("STEP 7: Generating Visualizations")
  
  # Set theme
  theme_set(theme_minimal(base_size = 12))
  
  # 1. Blood Sugar vs Age
  p1 <- ggplot(train_data, aes(x = Age, y = BloodSugar)) +
    geom_point(alpha = 0.5, color = "#2C3E50") +
    geom_smooth(method = "lm", se = TRUE, color = "#E74C3C", fill = "#E74C3C", alpha = 0.2) +
    labs(title = "Blood Sugar vs Age",
         subtitle = "Training Data",
         x = "Age (years)", 
         y = "Blood Sugar (mg/dL)") +
    theme_minimal()
  
  ggsave(file.path(config$output$plots_dir, "bloodsugar_vs_age.png"), 
         p1, width = 8, height = 6, dpi = 300)
  
  # 2. Blood Sugar vs BMI
  p2 <- ggplot(train_data, aes(x = BMI, y = BloodSugar)) +
    geom_point(alpha = 0.5, color = "#2C3E50") +
    geom_smooth(method = "lm", se = TRUE, color = "#3498DB", fill = "#3498DB", alpha = 0.2) +
    labs(title = "Blood Sugar vs BMI",
         subtitle = "Training Data",
         x = "BMI (kg/m²)", 
         y = "Blood Sugar (mg/dL)") +
    theme_minimal()
  
  ggsave(file.path(config$output$plots_dir, "bloodsugar_vs_bmi.png"),
         p2, width = 8, height = 6, dpi = 300)
  
  # 3. Predicted Probability Distribution
  p3 <- ggplot(val_data, aes(x = prob_diabetes, fill = Diabetes)) +
    geom_histogram(alpha = 0.7, bins = 30, position = "identity") +
    scale_fill_manual(values = c("#2ECC71", "#E74C3C")) +
    labs(title = "Predicted Probability Distribution",
         subtitle = "Validation Set",
         x = "Predicted Probability of Diabetes",
         y = "Count") +
    theme_minimal()
  
  ggsave(file.path(config$output$plots_dir, "probability_distribution.png"),
         p3, width = 8, height = 6, dpi = 300)
  
  # 4. ROC Curve
  roc_data <- data.frame(
    fpr = 1 - roc_obj$specificities,
    tpr = roc_obj$sensitivities
  )
  
  p4 <- ggplot(roc_data, aes(x = fpr, y = tpr)) +
    geom_line(color = "#E74C3C", size = 1.2) +
    geom_abline(linetype = "dashed", color = "gray50") +
    annotate("text", x = 0.7, y = 0.3, 
             label = sprintf("AUC = %.3f", auc_score),
             size = 5, color = "#E74C3C") +
    labs(title = "ROC Curve - Diabetes Prediction",
         subtitle = "Validation Set",
         x = "False Positive Rate (1 - Specificity)",
         y = "True Positive Rate (Sensitivity)") +
    coord_fixed() +
    theme_minimal()
  
  ggsave(file.path(config$output$plots_dir, "roc_curve.png"),
         p4, width = 8, height = 6, dpi = 300)
  
  # 5. Feature Importance (Odds Ratios)
  or_plot_data <- or_table %>%
    filter(term != "(Intercept)") %>%
    mutate(significant = p.value < 0.05)
  
  p5 <- ggplot(or_plot_data, aes(x = reorder(term, estimate), y = estimate, fill = significant)) +
    geom_col() +
    geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    scale_fill_manual(values = c("gray70", "#E74C3C")) +
    coord_flip() +
    labs(title = "Odds Ratios for Diabetes Risk Factors",
         subtitle = "Values > 1 indicate increased risk",
         x = "Predictor",
         y = "Odds Ratio",
         fill = "Significant (p < 0.05)") +
    theme_minimal()
  
  ggsave(file.path(config$output$plots_dir, "odds_ratios.png"),
         p5, width = 8, height = 6, dpi = 300)
  
  logger::log_info("All visualizations saved")
  
  # ===== GENERATE REPORT =====
  logger::log_info("STEP 8: Generating Final Report")
  
  model_info <- list(
    version = config$model$version,
    auc = test_auc,
    metrics = test_metrics
  )
  
  generate_report(
    model_info,
    file.path(config$output$reports_dir, "model_evaluation_report.txt")
  )
  
  # ===== SAVE METADATA =====
  metadata <- list(
    model_version = config$model$version,
    training_date = as.character(Sys.time()),
    training_samples = nrow(train_data),
    validation_samples = nrow(val_data),
    test_samples = nrow(test_data),
    features = config$features$predictors,
    validation_auc = auc_score,
    test_auc = test_auc,
    test_metrics = test_metrics[c("accuracy", "sensitivity", "specificity", "precision", "f1_score")],
    validation_passed = validation_passed
  )
  
  yaml::write_yaml(
    metadata,
    file.path(config$output$models_dir, "model_metadata.yaml")
  )
  logger::log_info("Model metadata saved")
  
  # ===== COMPLETION =====
  logger::log_info("=" %>% rep(70) %>% paste(collapse = ""))
  logger::log_info("TRAINING PIPELINE COMPLETED SUCCESSFULLY")
  logger::log_info("=" %>% rep(70) %>% paste(collapse = ""))
  
  return(invisible(list(
    linear_model = lm_model,
    logistic_model = glm_model,
    metrics = test_metrics,
    auc = test_auc,
    metadata = metadata
  )))
}

# Execute if run as script
if (!interactive()) {
  result <- main()
}
