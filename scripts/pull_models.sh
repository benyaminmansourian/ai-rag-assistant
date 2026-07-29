#!/bin/bash
# =========================================================
# pull_models.sh - Pull required Ollama models (LLM + embedding)
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
source "$ENV_FILE"

echo ">>> Pulling LLM model: ${DEFAULT_MODEL}"
docker exec rag_ollama ollama pull "${DEFAULT_MODEL}"

echo ">>> Pulling embedding model: ${EMBEDDING_MODEL}"
docker exec rag_ollama ollama pull "${EMBEDDING_MODEL}"

echo ">>> Installed models:"
docker exec rag_ollama ollama list
