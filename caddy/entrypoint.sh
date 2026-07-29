#!/bin/sh
set -eu

echo "[entrypoint] Generating Caddyfile from template using environment variables..."

: "${DOMAIN:?DOMAIN must be set}"
: "${EMAIL:?EMAIL must be set}"

envsubst '${DOMAIN} ${EMAIL} ${UPLOAD_MAX_SIZE} ${CADDY_RATE_LIMIT_REQUESTS} ${CADDY_RATE_LIMIT_WINDOW}' \
  < /etc/caddy/Caddyfile.template > /etc/caddy/Caddyfile

echo "[entrypoint] Final Caddyfile generated:"
cat /etc/caddy/Caddyfile

echo "[entrypoint] Starting Caddy..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
