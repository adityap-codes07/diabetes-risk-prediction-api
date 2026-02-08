FROM rocker/r-ver:4.3.2

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c( \
    'mlbench', \
    'tidyverse', \
    'broom', \
    'car', \
    'pROC', \
    'logger', \
    'yaml', \
    'jsonlite', \
    'plumber' \
    ), repos='https://cloud.r-project.org/')"

# Copy application files
COPY config.yaml /app/
COPY utils.R /app/
COPY train_model.R /app/
COPY predict.R /app/
COPY api.R /app/
COPY run_api.R /app/

# Create necessary directories
RUN mkdir -p /app/results /app/models /app/logs /app/plots /app/reports

# Expose API port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run API server
CMD ["Rscript", "run_api.R"]
