# Makefile for Diabetes Risk Prediction Model

.PHONY: help install train test api docker-build docker-run docker-compose-up clean

help:
	@echo "Diabetes Risk Prediction Model - Makefile Commands"
	@echo "=================================================="
	@echo "make install          - Install R dependencies"
	@echo "make train            - Train the model"
	@echo "make test             - Run tests"
	@echo "make api              - Start the API server"
	@echo "make docker-build     - Build Docker image"
	@echo "make docker-run       - Run Docker container"
	@echo "make docker-compose-up - Start with Docker Compose"
	@echo "make monitor          - Run monitoring setup"
	@echo "make clean            - Clean generated files"
	@echo "make all              - Install, train, and test"

install:
	@echo "Installing R dependencies..."
	Rscript -e "install.packages(c('mlbench', 'tidyverse', 'broom', 'car', 'pROC', 'logger', 'yaml', 'jsonlite', 'plumber', 'testthat'), repos='https://cloud.r-project.org/')"
	@echo "Dependencies installed successfully!"

train:
	@echo "Training the model..."
	Rscript train_model.R
	@echo "Training completed!"

test:
	@echo "Running tests..."
	Rscript tests.R
	@echo "Tests completed!"

api:
	@echo "Starting API server..."
	Rscript run_api.R

monitor:
	@echo "Setting up monitoring..."
	Rscript monitor.R
	@echo "Monitoring setup completed!"

docker-build:
	@echo "Building Docker image..."
	docker build -t diabetes-prediction-api:latest .
	@echo "Docker image built successfully!"

docker-run:
	@echo "Running Docker container..."
	docker run -d \
		--name diabetes-api \
		-p 8000:8000 \
		-v $(PWD)/models:/app/models \
		-v $(PWD)/logs:/app/logs \
		diabetes-prediction-api:latest
	@echo "Container running at http://localhost:8000"

docker-compose-up:
	@echo "Starting services with Docker Compose..."
	docker-compose up -d
	@echo "Services started! API available at http://localhost:8000"

docker-compose-down:
	@echo "Stopping Docker Compose services..."
	docker-compose down
	@echo "Services stopped!"

clean:
	@echo "Cleaning generated files..."
	rm -rf results/* models/* logs/* plots/* reports/*
	rm -f Rplots.pdf
	@echo "Cleaned!"

all: install train test
	@echo "All tasks completed successfully!"

quick-start: install train api
	@echo "Quick start completed! API is running."
