# =========================================================
# Stage 1: Build Caddy with the rate-limit plugin
# =========================================================
FROM caddy:2.8.4-builder-alpine AS builder

# Use an alternative Go module mirror to avoid proxy.golang.org 403 errors
# (common on IPs affected by GeoIP restrictions). Falls back to direct
# GitHub fetch if the mirror is unreachable.
ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=off

RUN xcaddy build \
    --with github.com/mholt/caddy-ratelimit

# =========================================================
# Stage 2: Final minimal runtime image
# =========================================================
FROM caddy:2.8.4-alpine

# Provide envsubst for template rendering + curl for healthcheck
RUN apk add --no-cache gettext curl

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

WORKDIR /etc/caddy