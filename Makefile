.PHONY: help install install-dev test test-unit test-property test-integration lint format clean

help:
	@echo "AI-SRE Incident Analysis System - Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install          Install production dependencies"
	@echo "  make install-dev      Install development dependencies"
	@echo ""
	@echo "Testing:"
	@echo "  make test             Run all tests with coverage"
	@echo "  make test-unit        Run unit tests only"
	@echo "  make test-property    Run property-based tests"
	@echo "  make test-integration Run integration tests"
	@echo "  make test-fast        Run tests without coverage (faster)"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint             Run all linters (flake8, mypy)"
	@echo "  make format           Format code with black and isort"
	@echo "  make format-check     Check formatting without changes"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean            Remove build artifacts and cache"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make tf-init          Initialize Terraform"
	@echo "  make tf-plan          Plan Terraform changes"
	@echo "  make tf-apply         Apply Terraform changes"
	@echo "  make tf-destroy       Destroy Terraform resources"

install:
	pip install -r requirements.txt

install-dev:
	pip install -r requirements-dev.txt

test:
	pytest

test-unit:
	pytest tests/unit/ -v

test-property:
	pytest tests/property/ -v

test-integration:
	pytest tests/integration/ -v

test-fast:
	pytest --no-cov -x

lint:
	@echo "Running flake8..."
	flake8 src/ tests/
	@echo "Running mypy..."
	mypy src/ --ignore-missing-imports

format:
	@echo "Formatting with black..."
	black src/ tests/
	@echo "Sorting imports with isort..."
	isort src/ tests/

format-check:
	@echo "Checking formatting..."
	black --check src/ tests/
	isort --check-only src/ tests/

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/
	rm -rf htmlcov/
	rm -rf .coverage
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete

tf-init:
	cd terraform/test-scenario && terraform init

tf-plan:
	cd terraform/test-scenario && terraform plan

tf-apply:
	cd terraform/test-scenario && terraform apply

tf-destroy:
	cd terraform/test-scenario && terraform destroy
