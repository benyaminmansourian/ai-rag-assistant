#!/bin/bash
# =========================================================
# update.sh - Pull latest pinned image digests, rebuild, and restart
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo ">>> Pulling latest images for pinned tags..."
docker compose pull

echo ">>> Rebuilding custom Caddy image..."
docker compose build --no-cache caddy

echo ">>> Recreating containers with zero-downtime rolling restart..."
docker compose up -d --remove-orphans

echo ">>> Pruning dangling images..."
docker image prune -f

echo ">>> Update complete. Current running versions:"
docker compose ps
