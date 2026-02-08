#!/usr/bin/env Rscript

# ==============================
# API Server Startup Script
# run_api.R
# ==============================

suppressPackageStartupMessages({
  library(plumber)
  library(logger)
  library(yaml)
  library(jsonlite)
  library(dplyr)
})

source("predict.R")

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("DIABETES RISK PREDICTION API\n")
cat(paste(rep("=", 70), collapse = ""), "\n")


# Load configuration
config <- load_config("config.yaml")
initialize_logger(config)

# Initialize and load predictor
logger::log_info("Initializing predictor...")
predictor <<- DiabetesPredictor$new("config.yaml")
predictor$load_models()
logger::log_info("Models loaded successfully")

# Create Plumber API
logger::log_info("Starting API server...")
pr <- plumb("api.R")

# Configure server
host <- config$api$host
port <- config$api$port

cat("\n")
cat("API Server Configuration:\n")
cat(sprintf("  Host: %s\n", host))
cat(sprintf("  Port: %s\n", port))
cat(sprintf("  Documentation: http://%s:%s/docs\n", 
            ifelse(host == "0.0.0.0", "localhost", host), port))
cat(sprintf("  Health Check: http://%s:%s/health\n", 
            ifelse(host == "0.0.0.0", "localhost", host), port))
cat("\n")

logger::log_info("API server running on {host}:{port}")
logger::log_info("Press Ctrl+C to stop the server")

# Run server
pr$run(host = host, port = port)
