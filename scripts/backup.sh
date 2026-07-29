#!/bin/bash
# =========================================================
# backup.sh - Backup PostgreSQL, Redis, Qdrant, Open WebUI, Ollama data
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
BACKUP_ROOT="$PROJECT_DIR/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

source "$ENV_FILE"

mkdir -p "$BACKUP_DIR"

echo ">>> Backing up PostgreSQL..."
docker exec rag_postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$BACKUP_DIR/postgres.sql.gz"

echo ">>> Backing up Redis (RDB snapshot)..."
docker exec rag_redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning SAVE
docker cp rag_redis:/data/dump.rdb "$BACKUP_DIR/redis_dump.rdb"

echo ">>> Backing up Qdrant snapshot..."
docker exec rag_qdrant sh -c "curl -s -X POST http://localhost:6333/snapshots -H 'api-key: $QDRANT_API_KEY'"
docker cp rag_qdrant:/qdrant/storage "$BACKUP_DIR/qdrant_storage"

echo ">>> Backing up Open WebUI data volume..."
docker run --rm -v rag_open_webui_data:/data -v "$BACKUP_DIR":/backup alpine \
  tar czf /backup/open_webui_data.tar.gz -C /data .

echo ">>> Backing up Ollama models volume..."
docker run --rm -v rag_ollama_data:/data -v "$BACKUP_DIR":/backup alpine \
  tar czf /backup/ollama_data.tar.gz -C /data .

echo ">>> Backing up Caddy TLS data..."
docker run --rm -v rag_caddy_data:/data -v "$BACKUP_DIR":/backup alpine \
  tar czf /backup/caddy_data.tar.gz -C /data .

echo ">>> Backup complete: $BACKUP_DIR"
