# AI Stack Changelog

## 2025-01-30 - Major Optimization & SearXNG Integration

### Stack Optimization
- **Removed**: All backup/restore functionality per requirements
- **Removed**: Hardware-specific references (Mac Mini M4) from documentation
- **Removed**: Unnecessary scripts (9 scripts → 1 setup.sh)
- **Removed**: Empty directories, .DS_Store files, IDE configs
- **Simplified**: 3 networks → 1 network (`ai-stack`)
- **Fixed**: Container naming (postgres → postgresql)
- **Migrated**: Open WebUI from SQLite to PostgreSQL

### Architecture Changes
- **Network**: Single bridge network with Docker DNS (no static IPs)
- **Database**: Single PostgreSQL instance with pgvector on all databases
- **Reverse Proxy**: Traefik implemented with self-signed SSL
- **Container Names**: Match product names exactly (no prefixes/suffixes)

### Services Added
- **Traefik**: Reverse proxy with HTTPS (https://*.local domains)
- **SearXNG**: Privacy-respecting web search for RAG

### Open WebUI Enhancements
- **Database**: Migrated to PostgreSQL (openwebui_db)
- **Filesystem Access**: 4 host directories mounted as env variables:
  - HOST_DOWNLOADS_PATH → /mnt/host/downloads
  - HOST_VIRIDAE_PATH → /mnt/host/viridae-network
  - HOST_DROPZONE_PATH → /mnt/host/dropzone
  - HOST_DOCSTORE_PATH → /mnt/host/docstore
- **Web Search**: Enabled RAG with SearXNG integration

### Ollama Configuration
- **Models**: Auto-download via init script
  - llama3.2:3b
  - qwen2.5:7b-instruct
  - nomic-embed-text

### Documentation
- **Created**: README.md (comprehensive user guide, no hardware refs)
- **Created**: ARCHITECTURE.md (design decisions and rationale)
- **Created**: TESTING.md (validation protocol with 50+ tests)
- **Created**: configs/searxng/README.md (SearXNG usage guide)
- **Created**: configs/open-webui/BRANDING.md (logo specifications)
- **Updated**: .env.example (clean, well-organized)
- **Simplified**: setup.sh (4-step process)

### Docker Images
- **PostgreSQL**: postgres:17.5 → pgvector/pgvector:pg17 (official)
- **All Images**: Verified as official (except n8n-mcp, user-approved)
- **SearXNG**: searxng/searxng:latest (official)
- **LiteLLM**: ghcr.io/berriai/litellm:main-stable (verified official)

### Configuration
- **Environment Variables**: Consolidated to .env
- **Resource Limits**: All configurable, no hardcoded values
- **Security**: No hardcoded credentials, all in .env (git-ignored)
- **Setup**: Reduced to < 5 steps

### Testing
- **Validation**: docker compose config - zero errors
- **Health Checks**: All services configured
- **Integration Tests**: End-to-end workflows documented

### Files Structure
```
ai-stack/
├── docker-compose.yml          # Single optimized file
├── .env                        # Your configuration (git-ignored)
├── .env.example               # Template
├── setup.sh                   # 4-step setup
├── README.md                  # User guide
├── ARCHITECTURE.md            # Design docs
├── TESTING.md                 # Validation
├── CHANGELOG.md               # This file
└── configs/
    ├── postgres/init-db.sql   # Database + pgvector
    ├── ollama/init-models.sh  # Model auto-download
    ├── traefik/*.yml          # Reverse proxy config
    ├── searxng/README.md      # Search engine guide
    └── open-webui/BRANDING.md # Logo specs
```

### Key Decisions

**Why Single Network?**
- Docker DNS handles service discovery
- Traefik manages external access
- Simpler troubleshooting
- Home lab doesn't need segmentation

**Why SearXNG?**
- Self-hosted (privacy-focused)
- No API keys or costs
- Official Docker image
- Aggregates 70+ search engines
- Native Open WebUI integration

**Why Single Compose File?**
- Simplicity for home lab
- Single command deployment
- All services visible
- Easier maintenance

**Why PostgreSQL for Everything?**
- Consistency across services
- pgvector for AI embeddings
- Centralized backups
- Better performance than SQLite

### Access URLs
- Open WebUI: https://open-webui.local
- n8n: https://n8n.local
- LiteLLM: https://litellm.local
- SearXNG: https://searxng.local
- Traefik: https://traefik.local

### /etc/hosts Entry
```
127.0.0.1 open-webui.local n8n.local litellm.local traefik.local ollama.local mcpo.local searxng.local
```

---

## Design Principles Established

1. **Simplicity First** - Minimal files, single compose, straightforward config
2. **Security by Default** - Reverse proxy with SSL, no hardcoded credentials
3. **Official Images Only** - Verified Docker images (documented exceptions)
4. **Privacy Focused** - All data local, no cloud dependencies
5. **Future-Ready** - Easy to extend with monitoring, additional services

## Troubleshooting Notes

### SearXNG Not Returning Results
- Check service health: `docker compose ps searxng`
- Test directly: `curl -k https://searxng.local/search?q=test`
- Verify Open WebUI env: `docker compose exec open-webui env | grep SEARCH`

### Open WebUI Filesystem Access Issues
- Verify paths in .env match your system
- Check mounts: `docker compose exec open-webui ls -la /mnt/host/`
- Test write: `docker compose exec open-webui touch /mnt/host/downloads/.test`

### PostgreSQL pgvector Issues
- Verify extension: `docker compose exec postgresql psql -U aistack -d openwebui_db -c "SELECT * FROM pg_extension WHERE extname='vector';"`
- Check databases: `docker compose exec postgresql psql -U aistack -c "\l"`

### Traefik Routing Issues
- Check dashboard: https://traefik.local
- Verify labels: `docker compose config | grep traefik.http.routers`
- Test direct access: `curl http://localhost:8080` (Open WebUI)

### Model Download Issues
- Manual download: `docker exec ollama ollama pull llama3.2:3b`
- Check available: `docker exec ollama ollama list`
- Monitor: `docker logs -f ollama`

---

## Future Enhancements

### Easy to Add
- **Monitoring**: Prometheus + Grafana (services ready with metrics)
- **Container Management**: Portainer
- **Remote Access**: Enable Let's Encrypt in Traefik
- **Additional Models**: Update configs/ollama/init-models.sh
- **More Host Directories**: Add to .env HOST_*_PATH variables

### Prepared Architecture
- Monitoring-ready (metrics endpoints exposed)
- Let's Encrypt ready (Traefik configured, commented out)
- Network supports additional services
- Label conventions for service discovery

---

## Version Information

- Docker Compose: V2 format
- PostgreSQL: 17.5 with pgvector
- Ollama: Latest with 3 models
- Open WebUI: main branch
- n8n: Latest
- LiteLLM: main-stable
- SearXNG: Latest
- Traefik: Latest

---

**Last Updated**: 2025-01-30
**Configuration Validated**: ✓ Zero errors
**Testing Status**: Ready for deployment validation
