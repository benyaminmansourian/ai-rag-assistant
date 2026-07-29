#!/bin/bash
# =========================================================
# restore.sh - Restore from a backup directory created by backup.sh
# Usage: ./restore.sh /path/to/backups/20260728_170000
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <backup_directory>"
  exit 1
fi

BACKUP_DIR="$1"
source "$ENV_FILE"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

echo ">>> Stopping stack..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" down

echo ">>> Restoring PostgreSQL..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d postgres
sleep 5
gunzip -c "$BACKUP_DIR/postgres.sql.gz" | docker exec -i rag_postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

echo ">>> Restoring Redis..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d redis
sleep 3
docker cp "$BACKUP_DIR/redis_dump.rdb" rag_redis:/data/dump.rdb
docker compose -f "$PROJECT_DIR/docker-compose.yml" restart redis

echo ">>> Restoring Qdrant storage..."
docker run --rm -v rag_qdrant_data:/data -v "$BACKUP_DIR":/backup alpine \
  sh -c "rm -rf /data/* && cp -r /backup/qdrant_storage/* /data/"

echo ">>> Restoring Open WebUI data..."
docker run --rm -v rag_open_webui_data:/data -v "$BACKUP_DIR":/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/open_webui_data.tar.gz -C /data"

echo ">>> Restoring Ollama models..."
docker run --rm -v rag_ollama_data:/data -v "$BACKUP_DIR":/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/ollama_data.tar.gz -C /data"

echo ">>> Restoring Caddy TLS data..."
docker run --rm -v rag_caddy_data:/data -v "$BACKUP_DIR":/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/caddy_data.tar.gz -C /data"

echo ">>> Bringing stack back up..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d

echo ">>> Restore complete."
