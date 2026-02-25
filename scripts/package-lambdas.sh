#!/bin/bash
# Package Lambda functions for deployment.
# Creates deployment.zip for each Lambda function containing:
#   - The function's lambda_function.py
#   - The shared/ directory (models, metrics, structured_logger, log_metadata)
#   - Per-function pip dependencies (only notification_service needs 'requests')
#
# Usage: ./scripts/package-lambdas.sh

set -euo pipefail

FUNCTIONS=(
  "metrics_collector"
  "logs_collector"
  "deploy_context_collector"
  "correlation_engine"
  "llm_analyzer"
  "notification_service"
)

# Packages to skip (pre-installed in Lambda runtime)
SKIP_PACKAGES="boto3 botocore s3transfer jmespath urllib3 python-dateutil six"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="${PROJECT_ROOT}/src"

echo "Packaging Lambda functions..."
echo "Project root: ${PROJECT_ROOT}"
echo ""

for func in "${FUNCTIONS[@]}"; do
  echo "=== Packaging ${func} ==="
  FUNC_DIR="${SRC_DIR}/${func}"
  BUILD_DIR="${FUNC_DIR}/build"

  # Clean previous build
  rm -rf "${BUILD_DIR}" "${FUNC_DIR}/deployment.zip"
  mkdir -p "${BUILD_DIR}"

  # Copy function code
  cp "${FUNC_DIR}/lambda_function.py" "${BUILD_DIR}/"

  # Copy shared modules
  cp -r "${SRC_DIR}/shared" "${BUILD_DIR}/shared"

  # Remove __pycache__ from shared
  find "${BUILD_DIR}/shared" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

  # Install per-function pip dependencies (skip boto3/botocore - pre-installed in Lambda)
  if [ -f "${FUNC_DIR}/requirements.txt" ]; then
    echo "  Installing dependencies from requirements.txt..."

    # Create a filtered requirements file (skip packages pre-installed in Lambda)
    FILTERED_REQ=$(mktemp)
    while IFS= read -r line || [ -n "$line" ]; do
      # Skip empty lines and comments
      [[ -z "$line" || "$line" =~ ^# ]] && continue

      # Extract package name (before any version specifier)
      pkg_name=$(echo "$line" | sed 's/[>=<!\[].*//; s/[[:space:]]//g')

      # Check if this package should be skipped
      skip=false
      for skip_pkg in $SKIP_PACKAGES; do
        if [ "$pkg_name" = "$skip_pkg" ]; then
          skip=true
          break
        fi
      done

      if [ "$skip" = false ]; then
        echo "$line" >> "$FILTERED_REQ"
      else
        echo "  Skipping ${pkg_name} (pre-installed in Lambda runtime)"
      fi
    done < "${FUNC_DIR}/requirements.txt"

    # Install filtered dependencies if any remain
    if [ -s "$FILTERED_REQ" ]; then
      pip install -r "$FILTERED_REQ" \
        -t "${BUILD_DIR}" \
        --quiet \
        --no-deps 2>&1 | grep -v "already satisfied" || true
    fi
    rm -f "$FILTERED_REQ"
  fi

  # Remove unnecessary files from build
  find "${BUILD_DIR}" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
  find "${BUILD_DIR}" -name "*.pyc" -delete 2>/dev/null || true
  find "${BUILD_DIR}" -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true

  # Create deployment.zip
  (cd "${BUILD_DIR}" && zip -r9q "${FUNC_DIR}/deployment.zip" .)

  # Clean build directory
  rm -rf "${BUILD_DIR}"

  # Report size
  ZIP_SIZE=$(du -h "${FUNC_DIR}/deployment.zip" | cut -f1)
  echo "  Created: deployment.zip (${ZIP_SIZE})"
  echo ""
done

echo "All Lambda packages created successfully."
