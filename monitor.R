# ==============================
# Model Monitoring & Drift Detection
# monitor.R
# ==============================

suppressPackageStartupMessages({
  library(logger)
  library(yaml)
  library(jsonlite)
})

source("utils.R")

#' ModelMonitor Class
#'
#' Monitors model performance and detects data drift
ModelMonitor <- setRefClass(
  "ModelMonitor",
  
  fields = list(
    config = "list",
    reference_stats = "list",
    drift_log = "list"
  ),
  
  methods = list(
    
    initialize = function(config_path = "config.yaml") {
      config <<- load_config(config_path)
      drift_log <<- list()
      logger::log_info("ModelMonitor initialized")
    },
    
    #' Calculate Reference Statistics from Training Data
    calculate_reference_stats = function(data) {
      numeric_cols <- names(data)[sapply(data, is.numeric)]
      
      stats <- list()
      for (col in numeric_cols) {
        stats[[col]] <- list(
          mean = mean(data[[col]], na.rm = TRUE),
          sd = sd(data[[col]], na.rm = TRUE),
          median = median(data[[col]], na.rm = TRUE),
          q25 = quantile(data[[col]], 0.25, na.rm = TRUE),
          q75 = quantile(data[[col]], 0.75, na.rm = TRUE),
          min = min(data[[col]], na.rm = TRUE),
          max = max(data[[col]], na.rm = TRUE)
        )
      }
      
      reference_stats <<- stats
      
      # Save reference stats
      stats_path <- file.path(config$output$models_dir, "reference_stats.yaml")
      yaml::write_yaml(stats, stats_path)
      logger::log_info("Reference statistics calculated and saved")
      
      return(stats)
    },
    
    #' Load Reference Statistics
    load_reference_stats = function() {
      stats_path <- file.path(config$output$models_dir, "reference_stats.yaml")
      if (!file.exists(stats_path)) {
        stop("Reference statistics not found. Run calculate_reference_stats first.")
      }
      
      reference_stats <<- yaml::read_yaml(stats_path)
      logger::log_info("Reference statistics loaded")
      return(reference_stats)
    },
    
    #' Detect Data Drift using Statistical Tests
    detect_drift = function(new_data, method = "ks") {
      if (length(reference_stats) == 0) {
        load_reference_stats()
      }
      
      drift_detected <- list()
      
      for (col in names(reference_stats)) {
        if (!col %in% names(new_data)) next
        
        if (method == "ks") {
          # Kolmogorov-Smirnov test
          # Create reference sample from saved stats (approximate)
          ref_mean <- reference_stats[[col]]$mean
          ref_sd <- reference_stats[[col]]$sd
          ref_sample <- rnorm(nrow(new_data), mean = ref_mean, sd = ref_sd)
          
          ks_test <- ks.test(new_data[[col]], ref_sample)
          
          drift_detected[[col]] <- list(
            p_value = ks_test$p.value,
            statistic = ks_test$statistic,
            drift = ks_test$p.value < 0.05
          )
          
        } else if (method == "mean_shift") {
          # Check for mean shift
          new_mean <- mean(new_data[[col]], na.rm = TRUE)
          ref_mean <- reference_stats[[col]]$mean
          ref_sd <- reference_stats[[col]]$sd
          
          # Z-score of mean difference
          z_score <- abs(new_mean - ref_mean) / (ref_sd / sqrt(nrow(new_data)))
          
          drift_detected[[col]] <- list(
            new_mean = new_mean,
            ref_mean = ref_mean,
            z_score = z_score,
            drift = z_score > 3  # 3-sigma threshold
          )
        }
      }
      
      # Log drift detection
      drift_summary <- data.frame(
        timestamp = Sys.time(),
        method = method,
        features_checked = length(drift_detected),
        features_drifted = sum(sapply(drift_detected, function(x) x$drift))
      )
      
      drift_log <<- c(drift_log, list(drift_summary))
      
      # Alert if significant drift
      if (drift_summary$features_drifted > 0) {
        logger::log_warn("Data drift detected in {drift_summary$features_drifted} feature(s)")
        
        for (col in names(drift_detected)) {
          if (drift_detected[[col]]$drift) {
            logger::log_warn("  - {col}: drift detected")
          }
        }
      } else {
        logger::log_info("No significant data drift detected")
      }
      
      return(drift_detected)
    },
    
    #' Monitor Model Performance
    monitor_performance = function(actual, predicted, threshold = 0.5) {
      metrics <- calculate_metrics(actual, predicted, threshold)
      
      # Load expected performance from metadata
      metadata_path <- file.path(config$output$models_dir, "model_metadata.yaml")
      if (file.exists(metadata_path)) {
        metadata <- yaml::read_yaml(metadata_path)
        expected_accuracy <- metadata$test_metrics$accuracy
        
        # Check for performance degradation
        degradation <- expected_accuracy - metrics$accuracy
        
        if (degradation > 0.05) {  # 5% threshold
          logger::log_warn("Performance degradation detected: {round(degradation * 100, 2)}% drop in accuracy")
          logger::log_warn("Expected: {round(expected_accuracy, 4)}, Current: {round(metrics$accuracy, 4)}")
        } else {
          logger::log_info("Model performance within expected range")
        }
      }
      
      # Log metrics
      performance_log <- data.frame(
        timestamp = Sys.time(),
        accuracy = metrics$accuracy,
        sensitivity = metrics$sensitivity,
        specificity = metrics$specificity,
        precision = metrics$precision,
        f1_score = metrics$f1_score
      )
      
      # Save performance log
      log_path <- file.path(config$output$logs_dir, "performance_log.csv")
      if (file.exists(log_path)) {
        existing_log <- read.csv(log_path)
        performance_log <- rbind(existing_log, performance_log)
      }
      write.csv(performance_log, log_path, row.names = FALSE)
      
      logger::log_info("Performance metrics logged")
      
      return(metrics)
    },
    
    #' Generate Monitoring Report
    generate_monitoring_report = function(output_path = NULL) {
      if (is.null(output_path)) {
        output_path <- file.path(config$output$reports_dir, 
                                 paste0("monitoring_report_", 
                                       format(Sys.time(), "%Y%m%d_%H%M%S"), 
                                       ".txt"))
      }
      
      report <- c(
        "=" %>% rep(70) %>% paste(collapse = ""),
        "MODEL MONITORING REPORT",
        "=" %>% rep(70) %>% paste(collapse = ""),
        "",
        sprintf("Generated: %s", Sys.time()),
        "",
        "--- DRIFT DETECTION SUMMARY ---"
      )
      
      if (length(drift_log) > 0) {
        drift_df <- do.call(rbind, drift_log)
        report <- c(report,
                   sprintf("Total checks: %d", nrow(drift_df)),
                   sprintf("Drift events: %d", sum(drift_df$features_drifted > 0)),
                   "")
      } else {
        report <- c(report, "No drift checks performed yet", "")
      }
      
      # Performance log
      log_path <- file.path(config$output$logs_dir, "performance_log.csv")
      if (file.exists(log_path)) {
        perf_log <- read.csv(log_path)
        report <- c(report,
                   "--- RECENT PERFORMANCE METRICS ---",
                   sprintf("Last check: %s", tail(perf_log$timestamp, 1)),
                   sprintf("Accuracy: %.4f", tail(perf_log$accuracy, 1)),
                   sprintf("Sensitivity: %.4f", tail(perf_log$sensitivity, 1)),
                   sprintf("Specificity: %.4f", tail(perf_log$specificity, 1)),
                   "")
      }
      
      report <- c(report,
                 "=" %>% rep(70) %>% paste(collapse = ""))
      
      writeLines(report, output_path)
      logger::log_info("Monitoring report saved: {output_path}")
      
      return(output_path)
    }
  )
)

# Example usage
if (!interactive()) {
  monitor <- ModelMonitor$new()
  
  # Load training data to calculate reference stats
  data("PimaIndiansDiabetes2", package = "mlbench")
  df <- PimaIndiansDiabetes2 %>%
    select(glucose, mass, age, insulin, pressure, pregnant, diabetes) %>%
    rename(BloodSugar = glucose, BMI = mass, Age = age, Diabetes = diabetes) %>%
    na.omit()
  
  # Calculate reference statistics
  monitor$calculate_reference_stats(df)
  
  cat("\nReference statistics calculated and saved.\n")
  cat("Use monitor$detect_drift(new_data) to check for drift in production data.\n")
}
