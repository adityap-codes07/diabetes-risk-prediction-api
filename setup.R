#!/usr/bin/env Rscript

# ==============================
# Environment Setup Script
# setup.R
# ==============================

cat(paste(rep("=", 70), collapse = ""), "\n")
cat("DIABETES RISK PREDICTION MODEL - ENVIRONMENT SETUP\n")
cat(paste(rep("=", 70), collapse = ""), "\n")

# Create necessary directories
dirs <- c(
  "results",
  "models",
  "logs",
  "plots",
  "reports"
)

cat("Creating directory structure...\n")
for (dir in dirs) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
    cat(sprintf("✓ Created: %s/\n", dir))
    
    # Create .gitkeep to preserve directory in git
    gitkeep_path <- file.path(dir, ".gitkeep")
    file.create(gitkeep_path)
  } else {
    cat(sprintf("  Exists: %s/\n", dir))
  }
}

cat("\n")

# Check R version
r_version <- getRversion()
cat(sprintf("R Version: %s\n", r_version))
if (r_version < "4.0.0") {
  cat("⚠ Warning: R version 4.0.0 or higher is recommended\n")
}

cat("\n")

# Check required packages
required_packages <- c(
  "mlbench",
  "tidyverse",
  "broom",
  "car",
  "pROC",
  "logger",
  "yaml",
  "jsonlite",
  "plumber",
  "testthat"
)

cat("Checking required packages...\n")
missing_packages <- c()

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("✗ Missing: %s\n", pkg))
    missing_packages <- c(missing_packages, pkg)
  } else {
    cat(sprintf("✓ Installed: %s\n", pkg))
  }
}

cat("\n")

if (length(missing_packages) > 0) {
  cat("Installing missing packages...\n")
  install.packages(missing_packages, repos = "https://cloud.r-project.org/")
  cat("Installation complete!\n\n")
} else {
  cat("All required packages are installed!\n\n")
}

# Validate configuration file
if (file.exists("config.yaml")) {
  cat("✓ Configuration file found: config.yaml\n")
} else {
  cat("✗ Configuration file not found: config.yaml\n")
  cat("  Please ensure config.yaml is in the working directory\n")
}

cat("\n")
cat("=" %>% rep(70) %>% paste(collapse = ""), "\n")
cat("SETUP COMPLETE!\n")
cat("=" %>% rep(70) %>% paste(collapse = ""), "\n")
cat("\nNext steps:\n")
cat("1. Review and customize config.yaml if needed\n")
cat("2. Train the model: Rscript train_model.R\n")
cat("3. Run tests: Rscript tests.R\n")
cat("4. Start API: Rscript run_api.R\n")
cat("\nOr use the Makefile:\n")
cat("  make all        # Install, train, and test\n")
cat("  make api        # Start the API server\n")
cat("\n")
