# Devcontainer Template

A secure, parameterized development container with egress firewall control.

## Features

- **Egress Firewall**: IP-based allowlisting using iptables/ipset
- **Persistent Caches**: Named volumes for shell history, pip, uv, pnpm caches
- **Pre-configured Tools**: zsh, git-delta, fzf, GitHub CLI, fnm, pnpm
- **Optional AI CLIs**: Claude, Amp, Factory (comment out in Dockerfile if not needed)

## Configuration

### Build-time Variables

All build-time variables are configured in `.devcontainer/devcontainer.json`:

| Variable | Location | Default | Description |
|----------|----------|---------|-------------|
| `TZ` | `build.args` | `UTC` | Container timezone |
| `USER_UID` | `build.args` | `1000` | Container user UID (match host for permissions) |
| `USER_GID` | `build.args` | `1000` | Container user GID |
| `USE_BUN` | `build.args` | `false` | Also install Bun alongside Node.js |
| `NODE_VERSION` | `build.args` | `22` | Node.js major version (installed via fnm) |
| `PYTHON_VERSION` | `features.python` | `3.13` | Python version |

To customize: edit `devcontainer.json` → rebuild. No env vars or sourcing needed.

### Runtime Variables

Set these in `.devcontainer/.env` (copy from `.devcontainer/.env.example`):

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_FIREWALL` | `false` | Set to `true` to enable egress restrictions |
| `FIREWALL_EXTRA_DOMAINS` | `` | Comma-separated list of additional domains to allow |

### Firewall Allowlist

The firewall allows traffic to:
- GitHub (API, web, git)
- npm registry
- PyPI (pypi.org, files.pythonhosted.org)
- VS Code Marketplace
- Anthropic API, Statsig
- Amp, Factory APIs

To add custom domains:
```bash
export FIREWALL_EXTRA_DOMAINS="api.example.com,cdn.example.org"
```

### Disabling the Firewall

For debugging or when you need unrestricted access:
```bash
export ENABLE_FIREWALL=false
```

## Security Notes

- The container runs as non-root user `dev` with passwordless sudo
- `NET_ADMIN` capability is required for the firewall - this means container processes *can* modify iptables
- The firewall is a policy enforcement tool, not a security sandbox against malicious code
- CLI installers (`curl | bash`) are unpinned - audit per your org's security policy

## Customization

### Adding Extensions

Edit `devcontainer.json` → `customizations.vscode.extensions`

### Removing AI CLIs

Comment out the unwanted lines in `Dockerfile` (near the end):
```dockerfile
# RUN curl -fsSL https://claude.ai/install.sh | bash
# RUN curl -fsSL https://ampcode.com/install.sh | bash
# RUN curl -fsSL https://app.factory.ai/cli | sh
```

### Changing the Base Image

The template uses `debian:bookworm-slim`. To change:
1. Update `FROM` in `Dockerfile`
2. Adjust package manager commands if not Debian-based

## Troubleshooting

### Firewall blocking needed traffic

1. Check which domain is blocked: `curl -v https://blocked-domain.com`
2. Add it: `export FIREWALL_EXTRA_DOMAINS="blocked-domain.com"`
3. Rebuild container or re-run: `sudo /usr/local/bin/init-firewall.sh`

### Container fails to start

If GitHub API or DNS is unreachable during startup, the firewall script will warn but continue. Check logs for warnings.

### Permission issues with mounted files

Ensure `USER_UID` and `USER_GID` match your host user:
```bash
export USER_UID=$(id -u)
export USER_GID=$(id -g)
```
