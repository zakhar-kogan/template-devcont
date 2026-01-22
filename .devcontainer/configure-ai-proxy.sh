#!/bin/bash
#!/bin/bash
# Configure supported AI coding tools to use a custom API proxy.
# Reads from AI_PROXY_BASE_URL and AI_PROXY_API_KEY environment variables
# or tool-specific overrides (ANTHROPIC_*, OPENCODE_*, DROID_*).

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get proxy settings (tool-specific overrides take precedence)
get_base_url() {
    local tool="$1"
    case "$tool" in
        claude)   echo "${ANTHROPIC_BASE_URL:-${AI_PROXY_BASE_URL:-}}" ;;
        opencode) echo "${OPENCODE_BASE_URL:-${AI_PROXY_BASE_URL:+${AI_PROXY_BASE_URL}/v1}}" ;;
        droid)    echo "${DROID_BASE_URL:-${AI_PROXY_BASE_URL:-}}" ;;
        *)        echo "${AI_PROXY_BASE_URL:-}" ;;
    esac
}

get_api_key() {
    local tool="$1"
    case "$tool" in
        claude)   echo "${ANTHROPIC_AUTH_TOKEN:-${AI_PROXY_API_KEY:-}}" ;;
        opencode) echo "${OPENCODE_API_KEY:-${AI_PROXY_API_KEY:-}}" ;;
        droid)    echo "${DROID_API_KEY:-${AI_PROXY_API_KEY:-}}" ;;
        *)        echo "${AI_PROXY_API_KEY:-}" ;;
    esac
}

get_provider() {
    echo "${DROID_PROVIDER:-anthropic}"
}

# Configure Claude Code
configure_claude() {
    local base_url api_key
    base_url=$(get_base_url claude)
    api_key=$(get_api_key claude)

    if [[ -z "$base_url" ]]; then
        log_warn "Claude: No proxy URL configured, skipping"
        return 0
    fi

    local config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local settings_file="$config_dir/settings.json"

    mkdir -p "$config_dir"

    local settings="{}"
    if [[ -f "$settings_file" ]]; then
        settings=$(cat "$settings_file" 2>/dev/null || echo "{}")
    fi

    local env_block
    env_block=$(jq -n \
        --arg base_url "$base_url" \
        --arg api_key "$api_key" \
        '{
            ANTHROPIC_BASE_URL: $base_url
        } + (if $api_key != "" then {ANTHROPIC_AUTH_TOKEN: $api_key} else {} end)'
    )

    echo "$settings" | jq --argjson env "$env_block" '. + {env: ((.env // {}) + $env)}' > "$settings_file"

    log_info "Claude: Configured to use $base_url"
}

# Configure OpenCode
configure_opencode() {
    local base_url api_key
    base_url=$(get_base_url opencode)
    api_key=$(get_api_key opencode)

    if [[ -z "$base_url" ]]; then
        log_warn "OpenCode: No proxy URL configured, skipping"
        return 0
    fi

    local config_dir="$HOME/.config/opencode"
    local config_file="$config_dir/opencode.json"
    local auth_file="$HOME/.local/share/opencode/auth.json"

    mkdir -p "$config_dir"
    mkdir -p "$(dirname "$auth_file")"

    local config="{}"
    if [[ -f "$config_file" ]]; then
        config=$(cat "$config_file" 2>/dev/null || echo "{}")
    fi

    local provider_config
    provider_config=$(jq -n \
        --arg base_url "$base_url" \
        '{
            provider: {
                "ai-proxy": {
                    npm: "@ai-sdk/openai-compatible",
                    name: "AI Proxy",
                    options: {
                        baseURL: $base_url
                    },
                    models: {
                        "gpt-4o": { name: "GPT-4o" },
                        "claude-sonnet-4": { name: "Claude Sonnet 4" },
                        "gemini-2.5-pro": { name: "Gemini 2.5 Pro" }
                    }
                }
            }
        }'
    )

    echo "$config" | jq --argjson provider "$provider_config" '. * $provider' > "$config_file"

    if [[ -n "$api_key" ]]; then
        local auth="{}"
        if [[ -f "$auth_file" ]]; then
            auth=$(cat "$auth_file" 2>/dev/null || echo "{}")
        fi

        echo "$auth" | jq --arg key "$api_key" '. + {"ai-proxy": {type: "api", key: $key}}' > "$auth_file"
    fi

    log_info "OpenCode: Configured to use $base_url"
}

# Configure Droid (Factory)
configure_droid() {
    local base_url api_key provider
    base_url=$(get_base_url droid)
    api_key=$(get_api_key droid)
    provider=$(get_provider)

    if [[ -z "$base_url" ]]; then
        log_warn "Droid: No proxy URL configured, skipping"
        return 0
    fi

    if [[ -z "$api_key" ]]; then
        log_warn "Droid: No API key configured, skipping"
        return 0
    fi

    local config_dir="$HOME/.factory"
    local settings_file="$config_dir/settings.json"

    mkdir -p "$config_dir"

    local settings="{}"
    if [[ -f "$settings_file" ]]; then
        settings=$(cat "$settings_file" 2>/dev/null || echo "{}")
    fi

    local custom_model
    custom_model=$(jq -n \
        --arg base_url "$base_url" \
        --arg api_key "$api_key" \
        --arg provider "$provider" \
        '{
            model: "proxy-model",
            displayName: "AI Proxy",
            baseUrl: $base_url,
            apiKey: $api_key,
            provider: $provider
        }'
    )

    echo "$settings" | jq --argjson model "$custom_model" '.customModels = ((.customModels // []) | map(select(.displayName != "AI Proxy")) + [$model])' > "$settings_file"

    log_info "Droid: Configured custom model pointing to $base_url"
}

# Main
main() {
    log_info "Configuring AI coding tools for proxy..."

    if [[ -z "${AI_PROXY_BASE_URL:-}" ]] && \
       [[ -z "${ANTHROPIC_BASE_URL:-}" ]] && \
       [[ -z "${OPENCODE_BASE_URL:-}" ]] && \
       [[ -z "${DROID_BASE_URL:-}" ]]; then
        log_warn "No AI proxy configuration found. Set AI_PROXY_BASE_URL or tool-specific vars."
        log_info "See .devcontainer/.env.example for options."
        exit 0
    fi

    configure_claude
    configure_opencode
    configure_droid

    log_info "AI proxy configuration complete!"
}

main "$@"
