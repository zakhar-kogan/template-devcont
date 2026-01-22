#!/usr/bin/env bash
# Generate a minimal production Dockerfile from the dev container setup
# Usage: ./scripts/generate-prod-dockerfile.sh [--with-node] [--output path]

set -euo pipefail

WITH_NODE=false
OUTPUT="Dockerfile.prod"

while [[ $# -gt 0 ]]; do
  case $1 in
    --with-node) WITH_NODE=true; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--with-node] [--output path]"
      echo "  --with-node  Include Node.js runtime"
      echo "  --output     Output file (default: Dockerfile.prod)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Extract versions from devcontainer.json if possible
PYTHON_VERSION="3.13"
NODE_VERSION="22"
if [[ -f .devcontainer/devcontainer.json ]]; then
  # Python version is in features.python.version
  PY_EXTRACTED=$(grep -A2 '"ghcr.io/devcontainers/features/python' .devcontainer/devcontainer.json | grep '"version"' | grep -o '[0-9.]*' || true)
  [[ -n "$PY_EXTRACTED" ]] && PYTHON_VERSION="$PY_EXTRACTED"
  
  # Node version is in build.args.NODE_VERSION
  NODE_EXTRACTED=$(grep '"NODE_VERSION"' .devcontainer/devcontainer.json | grep -o '[0-9]*' || true)
  [[ -n "$NODE_EXTRACTED" ]] && NODE_VERSION="$NODE_EXTRACTED"
fi

cat > "$OUTPUT" << 'DOCKERFILE_BASE'
# Production Dockerfile - auto-generated from dev container template
# Regenerate with: ./scripts/generate-prod-dockerfile.sh

FROM python:PYTHON_VERSION_PLACEHOLDER-slim-bookworm

WORKDIR /app

# Install only runtime dependencies (no dev tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

DOCKERFILE_BASE

# Add Node.js if requested
if [[ "$WITH_NODE" == "true" ]]; then
  cat >> "$OUTPUT" << DOCKERFILE_NODE
# Install Node.js
RUN apt-get update && apt-get install -y --no-install-recommends curl \\
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \\
    && apt-get install -y nodejs \\
    && apt-get clean && rm -rf /var/lib/apt/lists/* \\
    && npm install -g pnpm

DOCKERFILE_NODE
fi

cat >> "$OUTPUT" << 'DOCKERFILE_APP'
# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files first (cache layer)
COPY pyproject.toml uv.lock ./

# Install dependencies (production only)
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ ./src/

# Create non-root user
RUN useradd --create-home --shell /bin/bash app && chown -R app:app /app
USER app

# Default command - override in docker-compose or deployment config
# Examples:
#   CMD ["python", "-m", "src.main"]
#   CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
#   CMD ["gunicorn", "src.main:app", "-b", "0.0.0.0:8000"]
CMD ["python", "-m", "src.main"]
DOCKERFILE_APP

# Replace Python version placeholder
sed -i.bak "s/PYTHON_VERSION_PLACEHOLDER/$PYTHON_VERSION/g" "$OUTPUT" && rm -f "$OUTPUT.bak"

echo "✓ Generated $OUTPUT (Python $PYTHON_VERSION$([ "$WITH_NODE" == "true" ] && echo ", Node.js $NODE_VERSION"))"
echo ""
echo "Next steps:"
echo "  1. Generate requirements.txt: uv export --no-dev > requirements.txt"
echo "  2. Adjust the CMD to match your entrypoint"
echo "  3. Build: docker build -f $OUTPUT -t myapp:prod ."
