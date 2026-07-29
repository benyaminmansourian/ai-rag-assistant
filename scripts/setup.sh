#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup.sh — One-command bootstrap for the RAG AI Assistant stack
# (Open WebUI + Ollama + Qdrant + PostgreSQL + Redis + Caddy)
# ---------------------------------------------------------------------------

PROJECT_ROOT="/opt/ai-rag-assistant"
cd "$PROJECT_ROOT"

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

color() { printf "\033[%sm%s\033[0m\n" "$1" "$2"; }
info()  { color "1;34" "==> $1"; }
ok()    { color "1;32" "OK: $1"; }
warn()  { color "1;33" "WARN: $1"; }
err()   { color "1;31" "ERROR: $1"; }

# ---------------------------------------------------------------------------
# 0. Pre-flight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed. Install it with: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose v2 plugin not found. Install with: sudo apt-get install -y docker-compose-plugin"
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    err "openssl is required to generate secrets but was not found."
    exit 1
fi

ok "Docker, Docker Compose, and openssl are available."

# ---------------------------------------------------------------------------
# 1. Create .env from .env.example
# ---------------------------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
    warn "$ENV_FILE already exists — skipping creation. Delete it first if you want a fresh setup."
else
    if [ ! -f "$ENV_EXAMPLE" ]; then
        err "$ENV_EXAMPLE not found. Cannot bootstrap environment file."
        exit 1
    fi
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    ok "Created $ENV_FILE from $ENV_EXAMPLE."
fi

# Helper to set or update a key in .env safely
set_env_var() {
    local key="$1"
    local value="$2"
    if grep -qE "^${key}=" "$ENV_FILE"; then
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

get_env_var() {
    local key="$1"
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2-
}

# ---------------------------------------------------------------------------
# 2. Auto-generate secrets (only if placeholder/empty)
# ---------------------------------------------------------------------------
info "Generating secrets (existing non-empty values are kept)..."

gen_secret_if_needed() {
    local key="$1"
    local bytes="$2"
    local current
    current="$(get_env_var "$key")"
    local current_upper
    current_upper="$(echo "$current" | tr '[:lower:]' '[:upper:]')"
    if [ -z "$current" ] \
        || [[ "$current_upper" == *"YOUR-"*"-HERE"* ]] \
        || [[ "$current_upper" == "CHANGEME"* ]] \
        || [[ "$current_upper" == "CHANGE_ME"* ]] \
        || [[ "$current_upper" == *"CHANGE_ME"* ]]; then
        local secret
        secret="$(openssl rand -hex "$bytes")"
        set_env_var "$key" "$secret"
        ok "Generated $key"
    else
        warn "$key already set — keeping existing value."
    fi
}

gen_secret_if_needed "WEBUI_SECRET_KEY" 32
gen_secret_if_needed "POSTGRES_PASSWORD" 24
gen_secret_if_needed "REDIS_PASSWORD" 24
gen_secret_if_needed "QDRANT_API_KEY" 24

# ---------------------------------------------------------------------------
# 3. Prompt for human-decision values (DOMAIN, EMAIL)
# ---------------------------------------------------------------------------
info "A few values need your input."

current_domain="$(get_env_var "DOMAIN")"
if [ -z "$current_domain" ] || [[ "$current_domain" == *"example.com"* ]]; then
    read -rp "Enter your DOMAIN (must resolve via DNS to this server, e.g. rag.example.com): " domain_input
    if [ -z "$domain_input" ]; then
        err "DOMAIN cannot be empty."
        exit 1
    fi
    set_env_var "DOMAIN" "$domain_input"
else
    ok "DOMAIN already set to: $current_domain"
fi

current_email="$(get_env_var "EMAIL")"
if [ -z "$current_email" ] || [[ "$current_email" == *"example.com"* ]]; then
    read -rp "Enter your EMAIL (for Let's Encrypt certificate notifications): " email_input
    if [ -z "$email_input" ]; then
        err "EMAIL cannot be empty."
        exit 1
    fi
    set_env_var "EMAIL" "$email_input"
else
    ok "EMAIL already set to: $current_email"
fi

# First-run signup must be enabled so the first admin account can be created
current_signup="$(get_env_var "ENABLE_SIGNUP")"
if [ -z "$current_signup" ]; then
    set_env_var "ENABLE_SIGNUP" "true"
fi

chmod +x $PROJECT_ROOT/scripts/*.sh

ok "Environment file ($ENV_FILE) is ready."

# ---------------------------------------------------------------------------
# 4. Build and start the stack
# ---------------------------------------------------------------------------
info "Building and starting the stack (docker compose up -d --build)..."
docker compose up -d --build

info "Waiting for core services to become healthy..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until docker compose ps --format '{{.Name}} {{.Health}}' 2>/dev/null | grep -qv "starting\|unhealthy" ; do
    ATTEMPTS=$((ATTEMPTS+1))
    if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
        warn "Services are still starting after $((MAX_ATTEMPTS*5))s. Check 'docker compose ps' and 'docker compose logs'."
        break
    fi
    sleep 5
done

ok "Stack is up. Current status:"
docker compose ps

# ---------------------------------------------------------------------------
# 5. Pull default models
# ---------------------------------------------------------------------------
if [ -x "./scripts/pull_models.sh" ]; then
    info "Pulling default Ollama models (this may take a while)..."
    ./scripts/pull_models.sh || warn "Model pulling failed — you can retry later with ./scripts/pull_models.sh"
else
    warn "scripts/pull_models.sh not found or not executable — skipping model pull."
fi

# ---------------------------------------------------------------------------
# 6. Done
# ---------------------------------------------------------------------------
DOMAIN_FINAL="$(get_env_var "DOMAIN")"
echo
ok "Setup complete!"
echo
echo "Next steps:"
echo "  1. Browse to: https://${DOMAIN_FINAL}"
echo "  2. Create your admin account (first signup becomes admin)."
echo "  3. Immediately set ENABLE_SIGNUP=false in .env and run:"
echo "       docker compose up -d open-webui"
echo "  4. Go to Admin Settings -> Documents to configure RAG (Ollama + Qdrant)."
echo "  5. Upload your documents under Workspace -> Knowledge."
echo
echo "See README.md for full details on backup, restore, update, and troubleshooting."
