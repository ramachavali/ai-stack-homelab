# AI Stack Architecture

This document explains design decisions, architecture patterns, and rationale behind the AI Stack implementation.

## Design Principles

1. **Simplicity First** - Single compose file, minimal scripts, straightforward configuration
2. **Security by Default** - Reverse proxy with SSL, no hardcoded credentials, principle of least privilege
3. **Official Images Only** - Use verified Docker images from official sources (with documented exceptions)
4. **Privacy Focused** - All data stays local, no cloud dependencies, filesystem isolation
5. **Future-Ready** - Easy to extend with monitoring, additional services, remote access

## Docker Image Policy

### Official Images Used ✓

| Service | Image | Source | Verification |
|---------|-------|--------|--------------|
| PostgreSQL | `pgvector/pgvector:pg17` | Docker Hub | Official pgvector extension image |
| Redis | `redis:latest` | Docker Hub | Docker Official Image |
| Ollama | `ollama/ollama:latest` | Docker Hub | Official Ollama vendor |
| n8n | `n8nio/n8n:latest` | Docker Hub | Official n8n vendor |
| Open WebUI | `ghcr.io/open-webui/open-webui:main` | GitHub Container Registry | Official Open WebUI vendor |
| LiteLLM | `ghcr.io/berriai/litellm:main-stable` | GitHub Container Registry | Official BerriAI/LiteLLM vendor |
| Traefik | `traefik:latest` | Docker Hub | Docker Official Image |
| MCPO | `ghcr.io/open-webui/mcpo:main` | GitHub Container Registry | Official Open WebUI MCP orchestrator |

### Approved Exception ⚠️

| Service | Image | Status | Justification |
|---------|-------|--------|---------------|
| n8n-mcp | `ghcr.io/czlonkowski/n8n-mcp:latest` | Third-party | Required for MCP integration with n8n. No official alternative exists. User approved. |

**Recently Added**:
| Service | Image | Status | Justification |
|---------|-------|--------|---------------|
| SearXNG | `searxng/searxng:latest` | ✓ Official | Official SearXNG metasearch engine (Docker Hub verified publisher) |

## Compose File Architecture

### Decision: Single Compose File

**Chosen**: Single `docker-compose.yml`

**Alternatives Considered**:
- Multiple files (base + overrides for dev/prod)
- Separate files per service group

**Rationale**:
- **Simplicity**: Home lab environment, not multi-environment deployment
- **Easier maintenance**: All services visible in one file
- **Single command deployment**: `docker-compose up -d`
- **Less complexity**: No file merging, clear service relationships

**Trade-offs Accepted**:
- Can't easily toggle service groups (but can comment out services if needed)
- Single environment configuration (acceptable for home lab)

## Network Architecture

### Decision: Single Bridge Network

**Chosen**: One Docker bridge network (`ai-stack`)

**Previous**: Three networks (ai-network, backend, frontend) with static IPs

**Rationale**:
- **Docker DNS**: Services communicate via names, not IPs
- **Simplified routing**: No complex network segmentation needed
- **Traefik handles access**: Reverse proxy provides external access control
- **Easier troubleshooting**: Single network to debug
- **Home lab appropriate**: Not a multi-tenant production environment

**Network Flow**:
```
Internet/LAN → Traefik (80, 443) → Internal Services (via Docker DNS)
                   ↓
            Service Discovery (Docker labels)
```

**Security**:
- Only Traefik exposes ports to host
- Services isolated from host network
- Inter-service communication on private bridge
- Traefik enforces HTTPS and routing rules

## Database Architecture

### Decision: Single PostgreSQL with Multiple Databases

**Chosen**: One PostgreSQL instance, separate databases per service

**Databases Created**:
- `aistack_db` - Main database
- `n8n_db` - n8n workflows and data
- `litellm_db` - LiteLLM proxy configuration
- `openwebui_db` - Open WebUI users, conversations, settings

**Rationale**:
- **Resource efficiency**: One instance vs. multiple
- **Simplified management**: Single connection pool, single backup
- **pgvector extension**: Enabled on all databases for AI embeddings
- **Data isolation**: Separate databases provide logical separation
- **Cost-effective**: Reduced memory overhead

**Trade-offs**:
- Services share PostgreSQL resources
- Single point of failure (acceptable for home lab)
- Backup must include all databases

**Why PostgreSQL pgvector Image**:
- Official pgvector extension pre-installed
- Optimized for vector operations (AI embeddings)
- Eliminates manual extension installation
- Based on official PostgreSQL image

### Why Open WebUI Uses PostgreSQL (Not SQLite)

**Changed from**: SQLite
**Changed to**: PostgreSQL

**Rationale**:
1. **Consistency**: All services use same database engine
2. **Vector support**: pgvector for embeddings and RAG
3. **Concurrent access**: PostgreSQL handles multiple connections better
4. **Backups**: Centralized database backup strategy
5. **Performance**: Better for large conversation histories

## Reverse Proxy Architecture

### Decision: Traefik

**Chosen**: Traefik v3

**Alternative Considered**: Nginx Proxy Manager

**Rationale**:
| Feature | Traefik | Nginx Proxy Manager |
|---------|---------|---------------------|
| Docker Integration | Excellent (native labels) | Good (manual config) |
| Latest Technology | ✓ Modern, actively developed | ✓ But more traditional |
| Auto-configuration | ✓ Via Docker labels | Manual per-service setup |
| SSL Management | Built-in Let's Encrypt | Built-in Let's Encrypt |
| Config as Code | ✓ YAML + Labels | UI + some YAML |
| Complexity | Medium (learning curve) | Low (friendly UI) |

**User Preference**: Latest technology → Traefik chosen

**Traefik Features Used**:
- **Docker provider**: Automatic service discovery
- **Self-signed SSL**: For local HTTPS (.local domains)
- **Entry points**: HTTP (80) → HTTPS (443) redirect
- **Dashboard**: Web UI for monitoring routes
- **File provider**: Static and dynamic configuration

**Service Routing**:
Services expose routes via Docker labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.SERVICE.rule=Host(`SERVICE.local`)"
  - "traefik.http.routers.SERVICE.entrypoints=websecure"
  - "traefik.http.routers.SERVICE.tls=true"
```

**Future Let's Encrypt**:
Configuration prepared for easy migration to public SSL:
- Uncomment `certificatesResolvers` in traefik.yml
- Change from self-signed to ACME
- Point DNS to public IP

## SearXNG Web Search Integration

### Decision: Self-Hosted SearXNG

**Chosen**: SearXNG metasearch engine
**Purpose**: Enable Open WebUI RAG with real-time web data

**Why SearXNG over alternatives**:

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **SearXNG** | Self-hosted, no API keys, privacy-focused, aggregates multiple sources, official Docker image | Requires hosting (minimal resources) | ✓ **Chosen** |
| Google Custom Search | High quality | Costs money, API keys, privacy concerns | ✗ Rejected |
| Brave Search API | Privacy-focused | API keys, rate limits, external dependency | ✗ Rejected |
| DuckDuckGo API | Simple | Rate limited, lower quality vs aggregated | ✗ Rejected |

**Integration Pattern**:
```
Open WebUI → SearXNG (internal) → [Google, Bing, DDG, etc.] (external)
                ↓
         Aggregated Results
                ↓
    Ollama AI + Web Context → Enhanced Response
```

**Configuration**:
- `ENABLE_RAG_WEB_SEARCH=true` in Open WebUI
- `RAG_WEB_SEARCH_ENGINE=searxng`
- SearXNG query endpoint: `http://searxng:8080/search?q=<query>`
- Result count configurable via `RAG_WEB_SEARCH_RESULT_COUNT`

**Privacy Design**:
- All search queries processed on local infrastructure
- SearXNG anonymizes requests to upstream engines
- No tracking cookies
- No search history logging (default configuration)
- User controls which search engines are enabled

**Resource Impact**:
- Memory: ~100-150MB (minimal)
- CPU: Only during searches
- Network: External requests only when user initiates search
- Storage: ~50MB image + ~10MB config

**Trade-offs**:
- **Accepted**: Search queries leave network (to Google, Bing, etc.)
  - *Mitigation*: SearXNG anonymizes, no tracking cookies, multiple sources dilute tracking
- **Accepted**: Adds ~100ms latency to AI responses when search enabled
  - *Acceptable*: Only for queries requiring current data
- **Accepted**: Potential rate limiting from search engines
  - *Mitigation*: Aggregates multiple sources, caching, configurable result count

**User Control**:
- Feature toggleable in Open WebUI interface (per conversation)
- Can disable entirely via `ENABLE_RAG_WEB_SEARCH=false`
- SearXNG accessible directly at https://searxng.local for manual searches

## Ollama Model Management

### Decision: Separate Init Script

**Model Download**: Via init script, not baked into image

**Models Required**:
- `llama3.2:3b` - ~2GB, balanced performance
- `qwen2.5:7b-instruct` - ~4.7GB, complex tasks
- `nomic-embed-text` - ~274MB, embeddings for RAG

**Rationale**:
- **First-run automation**: Models download on first setup
- **Flexibility**: Easy to add/remove models
- **Image size**: Don't bloat Ollama image
- **Updates**: Pull new model versions independently
- **Idempotent**: Script checks if models exist before downloading

**Script Location**: `configs/ollama/init-models.sh`

**Alternative**: Could use health check + entrypoint, but script gives explicit control

## Open WebUI Filesystem Access

### Decision: Environment Variable Paths

**Chosen**: Paths defined in `.env`, mounted as read-write volumes

**Mounted Directories**:
```
HOST_DOWNLOADS_PATH → /mnt/host/downloads
HOST_VIRIDAE_PATH → /mnt/host/viridae-network
HOST_DROPZONE_PATH → /mnt/host/dropzone
HOST_DOCSTORE_PATH → /mnt/host/docstore
```

**Rationale**:
- **User-specific**: Each deployment can configure paths
- **Secure**: Explicit path declaration, not wildcards
- **Flexible**: Easy to add more mounts
- **Documented**: Clear in `.env.example` what to configure

**Security Considerations**:
- Read-write access (required for AI file operations)
- No access to system directories
- User controls which directories are exposed
- Paths must exist or mount fails (fail-safe)

## Container Naming Conventions

### Decision: Product Names Only

**Requirement**: Container names match product names exactly

**Examples**:
- `postgresql` (not `postgres`, not `ai-stack-postgresql`)
- `n8n` (not `n8n-service`)
- `open-webui` (not `openwebui`, not `open_webui`)

**Rationale**:
- **Clarity**: Obvious which service is which
- **No prefixes**: Cleaner, simpler names
- **Standard**: Matches how users refer to products
- **Docker network DNS**: Services discover each other by container name

**Note**: Image names may differ (e.g., `postgres:17.5` image → `postgresql` container)

## Resource Management

### Decision: Environment Variable Limits

**Chosen**: All resource limits configurable via `.env`

**Default Strategy**:
- Generous defaults for 32GB+ systems
- Comments in `.env.example` for different system sizes
- No hardcoded resource allocation

**Resource Limit Structure**:
```bash
SERVICE_MEMORY_LIMIT=<max>
SERVICE_CPU_LIMIT=<cores>
SERVICE_MEMORY_RESERVATION=<min>
SERVICE_CPU_RESERVATION=<cores>
```

**Rationale**:
- **Prevents OOM**: Docker enforces limits
- **Fair sharing**: Reservations guarantee minimum resources
- **Tunable**: Users adjust for their hardware
- **Documentation**: `.env.example` has guidance

**Key Services**:
- **Ollama**: 12G default (largest), adjust per model size
- **PostgreSQL**: 2G default, increase for heavy usage
- **n8n**: 3G default, depends on workflow complexity
- **Others**: 512M-1G, generally sufficient

## Security Architecture

### SSL/TLS Strategy

**Local Development**: Self-signed certificates
**Future Production**: Let's Encrypt via Traefik ACME

**Current Setup**:
- Generated via `openssl` in setup script
- Valid for `*.local` domains
- Browser warnings expected (user accepts once)

**Migration Path**:
1. Obtain public domain name
2. Point A record to public IP
3. Enable Let's Encrypt resolver in Traefik
4. Traefik auto-provisions valid SSL certs

### Secrets Management

**Current**: Environment variables in `.env` file

**Best Practices Enforced**:
- `.env` in `.gitignore`
- No default passwords in `.env.example`
- Key generation commands documented
- User prompted during setup

**Future Enhancement**:
Could migrate to Docker Secrets:
```yaml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

**Not Implemented**: Adds complexity for home lab, current approach acceptable

### Network Security

**Firewall Strategy**:
- Host exposes only ports 80, 443, 8090 (Traefik)
- All other services internal to Docker network
- Services cannot be accessed directly from host

**Service-to-Service**:
- Communication via Docker DNS (e.g., `http://ollama:11434`)
- No authentication between internal services (trust boundary)
- Traefik enforces HTTPS to external clients

## Backup Strategy

### Decision: No Built-in Backups

**Removed**: All backup/restore scripts and infrastructure

**Rationale**:
- **User requirement**: Explicitly requested removal
- **Simplicity**: Fewer moving parts
- **Flexibility**: Users implement own backup strategy
- **Docker volumes**: Easy to backup via standard tools

**Recommendations for Users**:
```bash
# Manual PostgreSQL backup
docker-compose exec postgresql pg_dumpall -U aistack > backup.sql

# Volume backup
docker run --rm -v postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres.tar.gz /data
```

**Future**: Could re-add optional backup service if needed

## Service Dependencies

### Dependency Chain

```
Traefik (no dependencies)
├─→ Exposes all services

PostgreSQL (no dependencies)
├─→ n8n
├─→ Open WebUI
├─→ LiteLLM

Redis (no dependencies)
├─→ n8n
├─→ LiteLLM

Ollama (no dependencies)
├─→ Open WebUI

n8n
├─→ n8n-mcp

n8n-mcp
├─→ MCPO
```

**Health Checks**:
All services have health checks. Dependent services wait for `service_healthy` condition.

**Startup Order**:
Docker Compose handles via `depends_on` with health conditions. Ensures PostgreSQL and Redis ready before dependent services start.

## Future Extensibility

### Monitoring Integration

**Prepared for**:
- Prometheus (service metrics)
- Grafana (visualization)
- Portainer (container management)

**Design**:
- Services already expose metrics endpoints
- n8n: `/metrics` endpoint (when enabled)
- LiteLLM: Built-in metrics
- PostgreSQL: postgres_exporter compatible
- Traefik: Prometheus metrics enabled

**To Add**:
```yaml
prometheus:
  image: prom/prometheus:latest
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  networks:
    - ai-stack

grafana:
  image: grafana/grafana:latest
  depends_on:
    - prometheus
  networks:
    - ai-stack
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.grafana.rule=Host(`grafana.local`)"
```

### Remote Access

**Current**: Local network only

**To Enable Remote Access**:
1. Update Traefik configuration:
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
```

2. Update router labels to use `letsencrypt` resolver:
```yaml
- "traefik.http.routers.SERVICE.tls.certresolver=letsencrypt"
```

3. Configure router port forwarding (80, 443)

4. Optional: Add authentication middleware
```yaml
- "traefik.http.routers.SERVICE.middlewares=auth@file"
```

### Additional Services

**Easy to Add**:
- Code Server (VS Code in browser)
- Jupyter notebooks
- Additional AI models
- Custom API services
- Database admin tools (pgAdmin)

**Pattern**:
1. Add service to `docker-compose.yml`
2. Connect to `ai-stack` network
3. Add Traefik labels for routing
4. Add environment variables to `.env.example`

## Testing Strategy

### Pre-Deployment Validation

**Syntax Check**:
```bash
docker-compose config
```
Validates YAML and environment variable substitution.

**Image Verification**:
- All images from official sources documented
- Exceptions explicitly approved

### Deployment Testing

**Health Checks**:
Every service has health check that verifies:
- Service responding to requests
- Dependencies available (database connection, etc.)

**Integration Testing**:
- Services can communicate (Open WebUI → Ollama)
- Database connections work
- Reverse proxy routes correctly
- SSL certificates valid

**Post-Deployment**:
See TESTING.md for comprehensive validation checklist.

## Trade-offs and Limitations

### Accepted Trade-offs

1. **Single Point of Failure**: PostgreSQL down = multiple services affected
   - *Acceptable*: Home lab, not production cluster

2. **No High Availability**: Single instance of each service
   - *Acceptable*: Cost of complexity not worth it for home lab

3. **Self-Signed SSL**: Browser warnings on first access
   - *Acceptable*: Local development, can upgrade to Let's Encrypt

4. **Resource Sharing**: Services compete for CPU/memory
   - *Mitigated*: Docker resource limits prevent one service starving others

5. **No Built-in Backups**: User responsible for data safety
   - *Acceptable*: User explicitly requested this

### Known Limitations

1. **n8n-mcp**: Third-party image (approved exception)
   - Monitor for security updates
   - Could replace if official image becomes available

2. **Local Only**: No remote access configured
   - Easy to enable (documented in this file)

3. **Fixed Model Set**: Models defined in init script
   - Easy to modify script to add more
   - Could parameterize in `.env` if needed

4. **No GPU Support**: Ollama using CPU only
   - Can be added via Docker GPU passthrough
   - Would require Docker Desktop GPU support

## Performance Considerations

### Expected Performance

**Ollama Response Times** (llama3.2:3b):
- Simple queries: 1-3 seconds
- Complex reasoning: 5-10 seconds
- Depends on CPU performance and available memory

**Database Queries**:
- n8n workflow execution: < 100ms
- Open WebUI conversation load: < 200ms
- PostgreSQL generally not bottleneck

**Web Interface Load Times**:
- Open WebUI: 1-2 seconds (first load)
- n8n: 2-3 seconds (workflow editor)
- Traefik dashboard: < 1 second

### Optimization Opportunities

**If Performance Issues**:
1. Increase Ollama memory allocation
2. Use smaller models (llama3.2:3b vs 7b)
3. Limit concurrent model loading (`OLLAMA_MAX_MODELS`)
4. Increase PostgreSQL shared buffers
5. Add Redis memory if LiteLLM slow
6. Monitor with `docker stats` to identify bottleneck

## Conclusion

This architecture balances:
- **Simplicity** (single compose file, minimal scripts)
- **Security** (reverse proxy, no hardcoded credentials)
- **Flexibility** (environment-based configuration)
- **Future-readiness** (easy to extend)
- **Best practices** (official images, health checks, resource limits)

Suitable for home lab deployment where ease of use and maintainability outweigh high availability requirements.
