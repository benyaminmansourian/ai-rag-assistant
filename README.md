# RAG AI Assistant — Production Docker Compose Stack

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/docker-compose-blue.svg" alt="Docker Compose">
  <img src="https://img.shields.io/badge/Open%20WebUI-RAG-orange.svg" alt="Open WebUI">
  <img src="https://img.shields.io/badge/Ollama-CPU%2FGPU-informational.svg" alt="Ollama">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome">
</p>

<p align="center">
  ⭐ If this project helped you, please consider giving it a <strong>star</strong> — it really helps others find it too!
</p>

A production-grade, self-hosted, general-purpose **RAG (Retrieval-Augmented Generation) AI Assistant**,
built on **Open WebUI + Ollama + Qdrant (RAG) + PostgreSQL + Redis**, fronted by
**Caddy** for automatic HTTPS, HTTP/2, HTTP/3, security headers, and rate limiting.

Bring the entire stack up with a single command, then simply upload your own
documents (playbooks, manuals, reports, policies, knowledge bases — anything)
and start chatting with an assistant that has learned your content.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Project Structure](#2-project-structure)
3. [One-Command Setup](#3-one-command-setup)
4. [Manual Configuration](#4-manual-configuration-optional-if-not-using-setupsh)
5. [Deploy](#5-deploy)
6. [First-Time Login & Locking Signup](#6-first-time-login--locking-signup)
7. [Add Ollama Models](#7-add-ollama-models)
8. [Enable RAG & Teach It Your Own Documents](#8-enable-rag--teach-it-your-own-documents)
9. [Backup](#9-backup)
10. [Restore](#10-restore)
11. [Update](#11-update)
12. [Security Notes](#12-security-notes)
13. [Troubleshooting](#13-troubleshooting)
14. [Version Pins](#14-version-pins-example-adjust-to-current-stable-releases)
15. [Contributing](#15-contributing)
16. [Support This Project](#16-support-this-project)
17. [License](#17-license)

---

## 1. Prerequisites

- A Linux server (Ubuntu 22.04/24.04 recommended) with at least 16 vCPU / 32GB RAM
  (CPU-only inference; more RAM/CPU improves large-model performance).
- A public DNS record (`A`/`AAAA`) pointing your `DOMAIN` to the server's IP.
- Open inbound ports **80/tcp**, **443/tcp**
- Root or sudo access.

### 1.1 Install Docker Engine

```bash
curl -fsSL https://get.docker.com | sh
```

### 1.2 Install Docker Compose (v2 plugin)

Docker Compose v2 ships as a plugin with modern Docker Engine installs above.
Verify with:

```bash
docker compose version
```

If missing, install manually:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

---

## 2. Project Structure

```
project/
├── docker-compose.yml
├── .env.example
├── caddy/
│   ├── Dockerfile
│   ├── Caddyfile.template
│   └── entrypoint.sh
├── scripts/
│   ├── setup.sh
│   ├── backup.sh
│   ├── restore.sh
│   ├── update.sh
│   └── pull_models.sh
├── data/
│   ├── postgres/
│   ├── redis/
│   ├── qdrant/
│   ├── ollama/
│   ├── open-webui/
│   └── caddy/
└── README.md
```

Note: `data/` subfolders are placeholders for documentation purposes; actual
persistence uses **named Docker volumes** (`rag_postgres_data`, `rag_redis_data`, etc.)
declared in `docker-compose.yml`, which is the recommended production approach over
plain bind mounts (permissions and driver portability).

---

## 3. One-Command Setup

This stack is designed so a new user can go from zero to a fully working,
document-aware AI assistant with the fewest possible manual steps.

```bash
git clone https://github.com/benyaminmansourian/ai-rag-assistant /opt/ai-rag-assistant && cd /opt/ai-rag-assistant
chmod +x /scripts/setup.sh
./scripts/setup.sh
```

`setup.sh` will:
1. Copy `.env.example` to `.env` (if it doesn't already exist).
2. Auto-generate all required secrets (`WEBUI_SECRET_KEY`, `POSTGRES_PASSWORD`,
   `REDIS_PASSWORD`, `QDRANT_API_KEY`) with `openssl rand -hex`.
3. Prompt you only for the values that truly need a human decision: `DOMAIN` and `EMAIL`.
4. Build and start the entire stack (`docker compose up -d --build`).
5. Pull the default chat and embedding models automatically.

Once it finishes, browse to `https://<DOMAIN>`, create your admin account
(the first user to sign up becomes admin), and start uploading documents.

If you prefer full manual control, skip `setup.sh` and follow sections 4–6 below.

---

## 4. Manual Configuration (optional, if not using setup.sh)

1. Copy the example environment file:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set **every** value — nothing is hardcoded in `docker-compose.yml`
   or `Caddyfile.template`:

   | Variable | Purpose |
   |---|---|
   | `DOMAIN` | Public FQDN used for TLS + reverse proxy |
   | `EMAIL` | Let's Encrypt account email |
   | `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | Open WebUI database credentials |
   | `REDIS_PASSWORD` | Redis AUTH password |
   | `QDRANT_API_KEY` | Qdrant API key for internal auth |
   | `WEBUI_SECRET_KEY` | Session signing secret (generate with `openssl rand -hex 32`) |
   | `DEFAULT_MODEL` | Default Ollama chat model (e.g. `qwen3:8b`) |
   | `EMBEDDING_MODEL` | Embedding model for RAG (`nomic-embed-text`) |
   | `RAG_EMBEDDING_ENGINE` | Embedding provider — set to `ollama` |
   | `ENABLE_SIGNUP` | `true` while creating the first admin, then set to `false` |
   | `TZ` | Timezone for all containers |
   | `UPLOAD_MAX_SIZE` | Max request body size for document uploads |
   | `CADDY_RATE_LIMIT_REQUESTS` / `CADDY_RATE_LIMIT_WINDOW` | Rate limiting thresholds |

3. Generate strong secrets:

   ```bash
   openssl rand -hex 32   # WEBUI_SECRET_KEY
   openssl rand -hex 24   # POSTGRES_PASSWORD / REDIS_PASSWORD / QDRANT_API_KEY
   ```

   Wrap any value containing spaces (like `WEBUI_NAME="My AI Assistant"`) in double quotes.

---

## 5. Deploy

```bash
cd project
docker compose up -d --build
```

This will:
- Build the custom Caddy image (with the `caddy-ratelimit` plugin).
- Start PostgreSQL, Redis, and Qdrant, waiting for healthy status.
- Start Ollama (CPU-only) and Open WebUI, waiting for dependencies.
- Start Caddy last, generating the final `Caddyfile` from the template via `envsubst`,
  then obtaining a Let's Encrypt certificate automatically for `DOMAIN`.

Check status:

```bash
docker compose ps
docker compose logs -f caddy
```

Once healthy, browse to `https://<DOMAIN>`.

---

## 6. First-Time Login & Locking Signup

1. `ENABLE_SIGNUP` must be `true` in `.env` for the very first account creation —
   this first account automatically becomes the admin.
2. Go to `https://<DOMAIN>` and create your admin account.
3. Immediately after, set `ENABLE_SIGNUP=false` in `.env` and run:

   ```bash
   docker compose up -d open-webui
   ```

4. Also double-check in **Admin Panel → Settings → Authentication → Enable New
   Sign Ups** that it is switched off — this in-database setting takes priority
   over the environment variable.

### Managing / removing users later

- **Admin Panel → Users**: delete any account, or promote a user to admin before
  removing the account you're currently logged in with (an admin cannot delete
  the account they're logged in as).
- To wipe all users and start over:

  ```bash
  docker compose stop open-webui
  docker exec -it rag_postgres psql -U <POSTGRES_USER> -d <POSTGRES_DB> -c "DELETE FROM \"user\";"
  docker compose start open-webui
  ```

---

## 7. Add Ollama Models

The `pull_models.sh` script pulls the default chat and embedding models defined in `.env`:

```bash
./scripts/pull_models.sh
```

To pull additional models manually:

```bash
docker exec rag_ollama ollama pull <model-name>
docker exec rag_ollama ollama list
```

Set a different default in Open WebUI's admin settings, or update `DEFAULT_MODEL`
in `.env` and run `docker compose up -d open-webui`.

**Model sizing guide (CPU-only inference):**

| Model | Approx. RAM | Notes |
|---|---|---|
| `phi4-mini` | ~4 GB | Fastest, good for quick Q&A |
| `qwen2.5:7b` | ~8 GB | Best balance of quality/speed for general assistants |
| `qwen3:8b` | ~8 GB | Strong reasoning, requires newer Ollama versions (≥ 0.9.x) |
| `deepseek-r1:8b` | ~8 GB | Best for step-by-step / chain-of-thought reasoning tasks |

If a model pull fails with a "requires a newer version of Ollama" error, bump the
`ollama/ollama` image tag in `docker-compose.yml` to a current release and re-run
`docker compose pull ollama && docker compose up -d ollama`.

---

## 8. Enable RAG & Teach It Your Own Documents

This is the core value of the stack: turning your own files into a searchable
knowledge base the assistant can cite from.

1. Go to **Admin Settings → Documents**:
   - **Embedding Model Engine**: `Ollama`
   - **API Base URL**: `http://ollama:11434` (use the Docker service name, not `localhost`)
   - **Embedding Model**: `nomic-embed-text` (or whatever you pulled)
   - **Vector Database**: `qdrant`, pointing to `http://qdrant:6333` (already wired via `.env`)
   - Click **Save** — even if values look correct, saving is required to apply them.
2. Go to **Workspace → Knowledge** and click **Create Collection**. Organize by topic,
   for example: "Product Docs", "Company Policies", "Support FAQs", "Reference Manuals".
3. Upload PDFs, Markdown, DOCX, or plain text files. Open WebUI automatically
   chunks, embeds, and stores them in Qdrant.
4. In any chat, type `#CollectionName` to pull that collection into context, or
   attach a file directly inline for a one-off question.
5. If you change the embedding model or engine after documents are already
   uploaded, re-upload (or re-index) affected files so their vectors match the
   new model.

### Optional: Live Web Search

By default, the assistant only knows what's in its training data and whatever
you've fed it via Knowledge — it cannot browse the internet. To let it fetch
live information:

```
Admin Panel → Settings → Web Search → Enable Web Search
```

Pick a provider such as `duckduckgo` (no API key required) or `searxng`/`tavily`/
`google_pse` (require an API key). Once enabled, toggle the web-search icon in
the chat input box before sending a message that needs current information.

---

## 9. Backup

```bash
./scripts/backup.sh
```

Creates a timestamped folder under `backups/` containing:
- `postgres.sql.gz` — full logical dump
- `redis_dump.rdb` — Redis AOF/RDB snapshot
- `qdrant_storage/` — raw vector collection storage
- `open_webui_data.tar.gz`, `ollama_data.tar.gz`, `caddy_data.tar.gz` — volume archives

Schedule via cron for nightly backups:

```bash
0 2 * * * /path/to/project/scripts/backup.sh >> /var/log/rag-ai-backup.log 2>&1
```

---

## 10. Restore

```bash
./scripts/restore.sh /path/to/backups/20260728_020000
```

This stops the stack, restores PostgreSQL/Redis/Qdrant/Open WebUI/Ollama/Caddy data,
and brings the stack back up.

---

## 11. Update

```bash
./scripts/update.sh
```

Pulls newer digests for pinned image tags, rebuilds the Caddy image, and performs a
rolling `docker compose up -d`. Always back up before updating, and review pinned
version tags in `docker-compose.yml` if you intend to bump major versions.

---

## 12. Security Notes

- Only Caddy exposes ports (`80/tcp`, `443/tcp`); every other service is
  reachable solely on the internal Docker network (e.g. `rag_internal_net`).
- All containers run with `restart: unless-stopped`, dropped Linux capabilities
  (`cap_drop: ALL` plus only the minimal `cap_add` required — for Redis this must
  include `CHOWN` and `DAC_OVERRIDE` so its entrypoint can fix volume ownership),
  and `security_opt: no-new-privileges:true`.
- Redis runs with a read-only root filesystem and a `tmpfs` for `/tmp`.
- Caddy's `admin off` and stripped `Server`/`X-Powered-By` headers hide version
  fingerprinting information.
- PostgreSQL, Redis, and Qdrant have no published host ports — access is
  container-to-container only.
- Rotate `WEBUI_SECRET_KEY`, database, and API-key secrets periodically; store
  `.env` outside version control (add it to `.gitignore`).
- Increase file-descriptor limits (`ulimits.nofile`) for `ollama` and `open-webui`
  services if you see `Too many open files` connection errors under load.

---

## 13. Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Caddy fails to issue certificate | DNS not pointing to server, or port 80/443 blocked | Verify `dig <DOMAIN>`, check firewall/security group rules |
| Open WebUI shows "Ollama not reachable" | Ollama still pulling model / not healthy yet | `docker compose logs ollama`, wait for healthcheck to pass |
| `pull model manifest: 412` error | Ollama version too old for the requested model | Bump `ollama/ollama` image tag, `docker compose pull ollama && up -d ollama` |
| `403 Forbidden` while pulling Ollama image | Docker Hub CDN restriction for your region | Configure a registry mirror in `/etc/docker/daemon.json`, retry, or try an older tag |
| "No embedding model is loaded" | `RAG_EMBEDDING_ENGINE`/`RAG_EMBEDDING_MODEL` unset or unsaved | Set Engine=Ollama, Base URL=`http://ollama:11434`, Model name, then Save |
| "You do not have permission to access this resource" on signup | `ENABLE_SIGNUP=false` blocking even the first admin | Temporarily set `ENABLE_SIGNUP=true`, create the admin, then set back to `false` |
| RAG returns no results | Embedding model not pulled, or Qdrant collection empty | Run `pull_models.sh`, re-upload documents to Knowledge |
| `502` from Caddy | Open WebUI container unhealthy or restarting | `docker compose logs open-webui`, check DB/Redis connectivity |
| Redis unhealthy: `Permission denied` on `appendonlydir` | Missing `CHOWN`/`DAC_OVERRIDE` capability, or stale volume ownership | Add capabilities in compose file; `docker run --rm -v rag_redis_data:/data alpine chown -R 999:999 /data` |
| `Cannot connect to host ollama:11434 ... Too many open files` | File-descriptor (ulimit) exhaustion | Add `ulimits.nofile` (soft/hard 65536) to `ollama` and `open-webui` services, restart stack |
| Slow inference | CPU-only large model is compute-heavy | Try a smaller model (`phi4-mini`, `qwen2.5:7b`), reduce `OLLAMA_NUM_PARALLEL`, or add more vCPU |
| Rate-limit errors during bulk uploads | `CADDY_RATE_LIMIT_REQUESTS` too low | Raise the value in `.env` and re-run `update.sh` |
| Postgres restarts in a loop | Wrong credentials after `.env` change | Ensure `POSTGRES_PASSWORD` matches existing volume data, or wipe volume for fresh init |

---

## 14. Version Pins (example, adjust to current stable releases)

| Service | Image | Tag |
|---|---|---|
| Caddy | `caddy` (custom build w/ ratelimit plugin) | `2.8.4-alpine` |
| Open WebUI | `ghcr.io/open-webui/open-webui` | `v0.11.0` |
| Ollama | `ollama/ollama` | `0.12.3` |
| PostgreSQL | `postgres` | `16.4-alpine` |
| Redis | `redis` | `7.4.0-alpine` |
| Qdrant | `qdrant/qdrant` | `v1.11.3` |

Review upstream release notes before bumping any of these in production.

---

## 15. Contributing

Contributions, issues, and feature requests are welcome!

- Found a bug or have an idea? [Open an issue](../../issues).
- Want to contribute code? Fork the repo, create a feature branch, and submit a
  [pull request](../../pulls).
- Please avoid committing your own `.env` file or secrets — `.env` is already
  covered by `.gitignore`.

If this project is useful to you, consider ⭐ **starring the repository** — it
helps others discover it and motivates continued maintenance.

---

---

## 16. Support This Project

If this project saved you time or helped your team, consider supporting its
development with a small crypto donation:

| Currency | Address |
|---|---|
| USDT (BEP-20) | `0xD18e0A300a758bdb9d64e321D3A2c80D76Ee27fd` |
| USDT (TRC-20) | `TUD2UytTuw3KsWSJfy73LHZ3HrCwFWtBSN` |
| Bitcoin | `bc1qrkxh9nw7ntru33687qwr36j9nq5nzky2eny5gg` |

> ⚠️ Double-check the network before sending — BEP-20 and TRC-20 addresses are
> **not interchangeable**. Sending USDT on the wrong network may result in
> permanent loss of funds.

Every bit of support helps keep this project maintained and free for everyone.
⭐ Starring the repo also helps a lot — it's free and takes two seconds.

---

## 17. License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE)
file for details. You are free to use, modify, and distribute this project,
including for commercial purposes, provided the original copyright and license
notice are retained.
