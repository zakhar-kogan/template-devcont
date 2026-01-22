.PHONY: build-dev build-prod test lint format check clean requirements

# Build dev container
build-dev:
	docker build -f .devcontainer/Dockerfile -t $(or $(IMAGE),myapp):dev .

# Generate and build production image
build-prod:
	./scripts/generate-prod-dockerfile.sh
	docker build -f Dockerfile.prod -t $(or $(IMAGE),myapp):prod .

# Build prod with Node.js
build-prod-node:
	./scripts/generate-prod-dockerfile.sh --with-node
	docker build -f Dockerfile.prod -t $(or $(IMAGE),myapp):prod .

# Run tests
test:
	uv run pytest

# Lint
lint:
	uv run ruff check src tests

# Format code
format:
	uv run ruff format src tests
	uv run ruff check --fix src tests

# Type check + lint (for CI)
check: lint test

# Generate requirements.txt for deployment
requirements:
	uv export --no-dev > requirements.txt

# Clean generated files
clean:
	rm -f Dockerfile.prod requirements.txt
	rm -rf .pytest_cache .ruff_cache __pycache__ src/__pycache__ tests/__pycache__
