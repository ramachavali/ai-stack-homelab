# AI Stack (Application Layer)

Private AI services stack that runs on top of `coreservices-homelab` (Traefik + shared `core-network`).

## Includes

- PostgreSQL + pgvector
- Redis
- Ollama
- Open WebUI
- n8n
- LiteLLM
- n8n-mcp + MCPO
- SearXNG
- PicoClaw
- AI portal (`portal.local`)

## Prerequisites

1. Docker daemon is running.
2. Core stack is running first (`../coreservices-homelab`) to provide:
   - `core-network`
   - Traefik routing/TLS
   - Shared Grafana at `https://grafana.local`

## Quick Start

```bash
cd /Users/rama/work/ai-stack-homelab
./scripts/setup.sh
./scripts/start.sh
```

## Hostnames

Add to `/etc/hosts` on your client machine:

```text
127.0.0.1 open-webui.local n8n.local litellm.local traefik.local ollama.local mcpo.local searxng.local portal.local picoclaw.local grafana.local
```

## Service URLs

- https://portal.local
- https://open-webui.local
- https://n8n.local
- https://litellm.local
- https://ollama.local
- https://mcpo.local
- https://searxng.local
- https://picoclaw.local/health

## Operations

```bash
./scripts/start.sh
./scripts/stop.sh
./scripts/backup.sh
./scripts/restore.sh
```

Useful checks:

```bash
docker-compose ps
docker-compose logs -f <service>
docker-compose config
```

## Configuration Source of Truth

- Environment template: `scripts/.unrendered.env`
- Rendered runtime env: `.rendered.env`
- Service definitions: `docker-compose.yml`
- App portal links: `services/app.py`
- PicoClaw config: `configs/picoclaw/config.json`

## Additional Docs

- `docs/installation-guide.md`
- `docs/project-structure.md`
- `ARCHITECTURE.md`
- `TESTING.md`
