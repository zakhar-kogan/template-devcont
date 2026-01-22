# Devcontainer Configuration

## Single Source of Truth

All build-time configuration is in `devcontainer.json` under `build.args` (and `features` for Python).

Edit → Rebuild → Done. No env vars or sourcing needed.

## Build-time Variables

| Variable | Location | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | `build.args` | `UTC` | Container timezone |
| `USER_UID` / `USER_GID` | `build.args` | `1000` | Container user IDs (match host) |
| `NODE_VERSION` | `build.args` | `22` | Node.js version (installed via fnm) |
| `USE_BUN` | `build.args` | `false` | Also install Bun alongside Node.js |
| `PYTHON_VERSION` | `features.python.version` | `3.13` | Python version |

## Runtime Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_FIREWALL` | `false` | Enable egress firewall restrictions |
| `FIREWALL_EXTRA_DOMAINS` | `` | Additional domains to allow through firewall |

## Python Version

Python is installed via the `ghcr.io/devcontainers/features/python:1` feature.

**Important**: Keep `PYTHON_VERSION` in sync with `pyproject.toml`:

```toml
# pyproject.toml
requires-python = ">=3.13"
target-version = "py313"  # ruff
```

## Node.js Version

Node.js is installed via [fnm](https://github.com/Schniz/fnm) with pnpm enabled via corepack.

fnm is initialized in `.zshrc` with `--use-on-cd`, so it will automatically switch Node versions if a `.node-version` or `.nvmrc` file is present.

## AI Proxy

See `.env.example` for AI proxy configuration options to redirect Claude, OpenCode, and other tools to a custom endpoint.
