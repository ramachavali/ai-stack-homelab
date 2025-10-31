# AI Stack - Private AI Infrastructure

Complete home lab AI environment featuring local AI models, workflow automation, chat interface, and AI integrations. Everything runs privately on your infrastructure with zero cloud dependencies.

## Services Included

- **PostgreSQL** with pgvector - Vector database for AI embeddings
- **Ollama** - Local AI model server (llama3.2:3b, qwen2.5:7b-instruct, nomic-embed-text)
- **Open WebUI** - ChatGPT-like web interface with filesystem access
- **n8n** - Workflow automation platform
- **LiteLLM** - Unified AI proxy for multiple providers
- **SearXNG** - Privacy-respecting web search engine for RAG
- **MCP Services** - Model Context Protocol integration (n8n-mcp, mcpo)
- **Traefik** - Reverse proxy with automatic HTTPS
- **Redis** - High-performance caching layer

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- 16GB+ RAM recommended
- 50GB+ free disk space
- macOS, Linux, or Windows with WSL2

### Installation

**1. Clone or download this repository**
```bash
cd ~/
git clone <repository-url> ai-stack
cd ai-stack
```

**2. Run setup**
```bash
./setup.sh
```

The setup script will:
- Verify Docker is running
- Create `.env` from template
- Prompt you to configure environment variables
- Download all Docker images
- Generate self-signed SSL certificates

**3. Configure `/etc/hosts`**

Add these entries to access services via friendly names:
```bash
sudo nano /etc/hosts
```

Add this line:
```
127.0.0.1 open-webui.local n8n.local litellm.local traefik.local ollama.local mcpo.local searxng.local
```

**4. Start the stack**
```bash
docker compose up -d
```

**5. Download AI models (runs in background)**
```bash
docker exec ollama sh /configs/ollama/init-models.sh
```

This downloads ~7GB of models and takes 10-20 minutes depending on your connection.

## Service Access

Once running, access services at:

| Service | URL | Purpose |
|---------|-----|---------|
| **Open WebUI** | https://open-webui.local | AI chat interface (primary) |
| **n8n** | https://n8n.local | Workflow automation |
| **LiteLLM** | https://litellm.local | AI proxy management |
| **SearXNG** | https://searxng.local | Web search engine |
| **Traefik** | https://traefik.local | Reverse proxy dashboard |
| **Ollama** | https://ollama.local | AI model API |
| **MCPO** | https://mcpo.local | MCP orchestrator |

**First-time setup:**
- Open WebUI: First user becomes admin
- n8n: First user becomes owner
- Accept self-signed certificate warnings in browser

## Configuration

### Environment Variables

All configuration is in `.env` file. Key variables:

**Database:**
```bash
POSTGRES_USER=aistack
POSTGRES_PASSWORD=<secure-password>
POSTGRES_DB=aistack_db
```

**Security Keys** (generate with `openssl rand -hex 16`):
```bash
N8N_ENCRYPTION_KEY=<32-char-hex>
OPEN_WEBUI_SECRET_KEY=<32-char-hex>
LITELLM_MASTER_KEY=<secure-key>
```

**Host Filesystem Mounts** (Open WebUI access):
```bash
HOST_DOWNLOADS_PATH=/Users/YOUR_USERNAME/Downloads
HOST_VIRIDAE_PATH=/Users/YOUR_USERNAME/Viridae Network
HOST_DROPZONE_PATH=/Users/YOUR_USERNAME/Library/Mobile Documents/com~apple~CloudDocs/DropZone
HOST_DOCSTORE_PATH=/Users/YOUR_USERNAME/Library/Mobile Documents/com~apple~CloudDocs/DocStore
```

Update `YOUR_USERNAME` with your actual username.

### Resource Limits

Adjust resource limits in `.env` based on your system:

**For systems with 16-32GB RAM:**
```bash
OLLAMA_MEMORY_LIMIT=8G
OLLAMA_MAX_MODELS=2
N8N_MEMORY_LIMIT=2G
POSTGRES_MEMORY_LIMIT=2G
```

**For systems with 32GB+ RAM:**
```bash
OLLAMA_MEMORY_LIMIT=12G
OLLAMA_MAX_MODELS=3
N8N_MEMORY_LIMIT=3G
POSTGRES_MEMORY_LIMIT=4G
```

## Daily Operations

### Starting and Stopping

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose stop

# Stop and remove containers (data persists)
docker compose down

# Stop and remove all data (DESTRUCTIVE)
docker compose down -v
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f open-webui
docker compose logs -f ollama
docker compose logs -f postgresql

# Last 100 lines
docker compose logs --tail=100
```

### Checking Service Status

```bash
# Service health
docker compose ps

# Resource usage
docker stats

# Verify models downloaded
docker exec ollama ollama list
```

### Restarting a Service

```bash
# Restart specific service
docker compose restart open-webui

# Restart after config changes
docker compose up -d --force-recreate open-webui
```

## Open WebUI Features

### Filesystem Access

Open WebUI has read-write access to your mounted directories. Files appear at:
- `/mnt/host/downloads` - Your Downloads folder
- `/mnt/host/viridae-network` - Viridae Network folder
- `/mnt/host/dropzone` - iCloud DropZone
- `/mnt/host/docstore` - iCloud DocStore

Use these paths when referencing files in conversations.

### Custom Branding

Place your logo files in `configs/open-webui/`:
- `favicon.png` (32x32px)
- `logo.png` (512x512px)
- `logo-dark.png` (512x512px, optional)

See [configs/open-webui/BRANDING.md](configs/open-webui/BRANDING.md) for details.

### AI Models

Ollama provides these models:
- **llama3.2:3b** - Fast, balanced model for general use
- **qwen2.5:7b-instruct** - Larger model for complex tasks
- **nomic-embed-text** - For document embeddings and RAG

Switch models in Open WebUI interface. Models load on first use.

## n8n Workflow Automation

### Filesystem Access

n8n has access to:
- `/home/node/dropzone` - iCloud DropZone
- `/home/node/docstore` - iCloud DocStore

Use these paths in File nodes for reading/writing files.

### Database Connection

n8n uses PostgreSQL database `n8n_db`. All workflows persist automatically.

### API Access

n8n API available at `https://n8n.local/api/v1/`

API key configured via `N8N_API_KEY` in `.env`

## SearXNG Web Search

### Privacy-Respecting Search

SearXNG enables Open WebUI to search the internet and use real-time web data in AI responses.

**Privacy Features**:
- Self-hosted - runs entirely on your infrastructure
- No tracking cookies
- Anonymizes requests to search engines
- No search history logging

### How It Works

```
Your Question → Open WebUI → SearXNG → [Google, Bing, DuckDuckGo, etc.]
                                 ↓
                         Aggregated Results
                                 ↓
                   Ollama AI + Web Context → Response
```

### Usage in Open WebUI

**Enable web search** in Open WebUI interface when asking questions that require current information:
- "What's the weather in Paris today?"
- "What are the latest developments in AI?"
- "Search for recent Docker best practices"

**Configuration**:
All settings in `.env`:
```bash
ENABLE_RAG_WEB_SEARCH=true
RAG_WEB_SEARCH_ENGINE=searxng
RAG_WEB_SEARCH_RESULT_COUNT=5
```

### Accessing SearXNG Directly

Navigate to https://searxng.local to:
- Perform manual searches
- Configure enabled search engines
- Adjust preferences

See [configs/searxng/README.md](configs/searxng/README.md) for advanced configuration.

## Troubleshooting

### Services Won't Start

**Check Docker:**
```bash
docker info
```

**Check logs:**
```bash
docker compose logs [service-name]
```

**Reset everything:**
```bash
docker compose down
docker system prune -f
docker compose up -d
```

### Can't Access Services

**Verify `/etc/hosts`:**
```bash
cat /etc/hosts | grep local
```

**Check Traefik is running:**
```bash
docker compose ps traefik
```

**Test direct access (bypass Traefik):**
```bash
curl http://localhost:8080  # Open WebUI direct
curl http://localhost:5678  # n8n direct
```

### Database Connection Errors

**Check PostgreSQL:**
```bash
docker compose logs postgresql
docker compose exec postgresql pg_isready
```

**Verify pgvector extension:**
```bash
docker compose exec postgresql psql -U aistack -d openwebui_db -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

### Ollama Models Not Working

**Check model download:**
```bash
docker exec ollama ollama list
```

**Download manually if missing:**
```bash
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull qwen2.5:7b-instruct
docker exec ollama ollama pull nomic-embed-text
```

**Check Ollama logs:**
```bash
docker compose logs -f ollama
```

### Out of Memory

**Check resource usage:**
```bash
docker stats --no-stream
```

**Reduce model memory in `.env`:**
```bash
OLLAMA_MEMORY_LIMIT=8G
OLLAMA_MAX_MODELS=2
```

**Unload unused models:**
```bash
docker exec ollama ollama stop llama3.2:3b
```

### Filesystem Mount Permission Errors

**Verify paths exist:**
```bash
ls -la "$HOME/Downloads"
ls -la "$HOME/Viridae Network"
```

**Check container can access:**
```bash
docker compose exec open-webui ls -la /mnt/host/
```

**Update `.env` with correct username:**
```bash
HOST_DOWNLOADS_PATH=/Users/YOUR_ACTUAL_USERNAME/Downloads
```

Then restart:
```bash
docker compose up -d --force-recreate open-webui
```

## Security Considerations

### Network Access

- All services behind Traefik reverse proxy
- Self-signed SSL certificates for local HTTPS
- Services communicate via internal Docker network
- Only Traefik exposes ports to host (80, 443, 8090)

### Credentials

- All passwords in `.env` file (git-ignored)
- Use strong, unique passwords
- Rotate API keys periodically
- Never commit `.env` to version control

### For Remote Access

**Not currently configured**. To enable:

1. Configure Let's Encrypt in Traefik
2. Set up port forwarding on router (80, 443)
3. Use dynamic DNS for your public IP
4. Update Traefik to use Let's Encrypt resolver
5. Consider adding authentication middleware

See [ARCHITECTURE.md](ARCHITECTURE.md) for details.

## Updating

### Update Docker Images

```bash
# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d --force-recreate

# Clean old images
docker image prune -f
```

### Update AI Models

```bash
# Check for model updates
docker exec ollama ollama pull llama3.2:3b
docker exec ollama ollama pull qwen2.5:7b-instruct
```

### Update Configuration

1. Edit `.env` with new values
2. Restart affected services:
```bash
docker compose up -d --force-recreate [service-name]
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for:
- Design decisions and rationale
- Network architecture
- Database schema
- Service dependencies
- Future extensibility

## Performance Tips

- Close unused applications while running AI workloads
- Use smaller models (llama3.2:3b) for faster responses
- Limit concurrent model usage with `OLLAMA_MAX_MODELS`
- Monitor disk space - models and data can grow large
- Restart Ollama periodically to free memory

## Adding Monitoring

Stack is designed to easily add monitoring tools:

**Prometheus + Grafana:**
```yaml
# Add to docker-compose.yml
prometheus:
  image: prom/prometheus
  # ... configuration

grafana:
  image: grafana/grafana
  # ... configuration
```

**Portainer:**
```yaml
portainer:
  image: portainer/portainer-ce
  ports:
    - "9443:9443"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - portainer_data:/data
```

All services already expose metrics endpoints for Prometheus scraping.

## Support

**Check logs first:**
```bash
docker compose logs -f [service-name]
```

**Verify configuration:**
```bash
docker compose config
```

**Health check:**
```bash
docker compose ps
curl -k https://open-webui.local/health
curl -k https://n8n.local/healthz
```

**Complete reset (nuclear option):**
```bash
docker compose down -v
rm -rf certs/
./setup.sh
docker compose up -d
```

---

**Your private AI infrastructure is ready.** Start by accessing https://open-webui.local and creating your admin account.
