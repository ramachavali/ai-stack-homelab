# AI Stack Testing Protocol

This document provides comprehensive testing procedures to validate your AI Stack deployment.

## Pre-Deployment Validation

### 1. Configuration Syntax Validation

```bash
docker-compose config
```

**Expected**: Clean YAML output with no errors or warnings.

**If errors**: Check `.env` file for missing or malformed variables.

### 2. Environment Variable Check

```bash
# Verify all required variables are set
grep "CHANGEME" .env
```

**Expected**: No output (all CHANGEME placeholders replaced).

**If found**: Update `.env` with actual values before proceeding.

### 3. Directory Structure

```bash
ls -la configs/
```

**Expected directories**:
- `postgres/` - Contains init-db.sql
- `ollama/` - Contains init-models.sh
- `traefik/` - Contains traefik.yml and dynamic.yml
- `mcp/` - Contains config files and entrypoint.sh
- `redis/` - Contains redis.conf (optional)
- `open-webui/` - Contains BRANDING.md

## Deployment Testing

### 1. Initial Deployment

```bash
# Clean slate (if re-testing)
docker-compose down -v

# Start all services
docker-compose up -d
```

**Expected**: All containers start without errors.

**Monitor startup**:
```bash
docker-compose logs -f
```

Look for initialization messages. Press Ctrl+C after 2-3 minutes.

### 2. Service Health Check

```bash
docker-compose ps
```

**Expected output**: All services show either "healthy" or "running" status.

**Example**:
```
NAME          STATUS                    PORTS
postgresql    Up (healthy)
redis         Up (healthy)
ollama        Up (healthy)
n8n           Up (healthy)
open-webui    Up (healthy)
litellm       Up (healthy)
n8n-mcp       Up (healthy)
mcpo          Up (healthy)
```

**If unhealthy**: Check specific service logs:
```bash
docker-compose logs [service-name]
```

### 3. Network Connectivity Test

```bash
# Test inter-service communication
docker-compose exec open-webui curl -s http://ollama:11434/api/tags | head -n 5
```

**Expected**: JSON response showing Ollama is reachable.

```bash
# Test PostgreSQL connectivity
docker-compose exec postgresql pg_isready -U aistack
```

**Expected**: `accepting connections`

## Service-Specific Validation

### PostgreSQL Database

**1. Verify databases exist**:
```bash
docker-compose exec postgresql psql -U aistack -d aistack_db -c "\l"
```

**Expected databases**:
- `aistack_db`
- `n8n_db`
- `litellm_db`
- `openwebui_db`

**2. Verify pgvector extension**:
```bash
docker-compose exec postgresql psql -U aistack -d openwebui_db -c "SELECT * FROM pg_extension WHERE extname='vector';"
```

**Expected**: One row showing vector extension installed.

**3. Test vector operations**:
```bash
docker-compose exec postgresql psql -U aistack -d openwebui_db -c "SELECT '[1,2,3]'::vector;"
```

**Expected**: Returns the vector representation.

### Ollama AI Models

**1. Check Ollama service**:
```bash
docker exec ollama ollama list
```

**Initially**: May show no models (models download separately).

**2. Download models** (run in background):
```bash
docker exec -d ollama sh -c "cd /root/.ollama && /configs/ollama/init-models.sh"
```

**Note**: This takes 10-20 minutes for ~7GB of models.

**3. Monitor download progress**:
```bash
docker logs -f ollama
```

**4. Verify models after download**:
```bash
docker exec ollama ollama list
```

**Expected models**:
- `llama3.2:3b`
- `qwen2.5:7b-instruct`
- `nomic-embed-text`

**5. Test model inference**:
```bash
docker exec ollama ollama run llama3.2:3b "Say hello in one word"
```

**Expected**: Model responds (e.g., "Hello!")

### Open WebUI

**1. Health check**:
```bash
curl -k https://open-webui.local/health
```

**Expected**: `{"status":"ok"}` or similar.

**2. Verify filesystem mounts**:
```bash
docker-compose exec open-webui ls -la /mnt/host/
```

**Expected directories**:
- `downloads`
- `viridae-network`
- `dropzone`
- `docstore`

**3. Test write permissions**:
```bash
docker-compose exec open-webui touch /mnt/host/downloads/.test && \
docker-compose exec open-webui rm /mnt/host/downloads/.test && \
echo "✓ Write permissions OK"
```

**4. Verify database connection**:
```bash
docker-compose logs open-webui | grep -i "database\|postgres"
```

**Expected**: Connection successful messages, no errors.

**5. Browser test**:
- Navigate to https://open-webui.local
- Accept self-signed certificate warning
- **Expected**: Login/signup page loads
- Create first user (becomes admin)
- Verify models appear in dropdown

### n8n Workflow Automation

**1. Health check**:
```bash
curl -k https://n8n.local/healthz
```

**Expected**: HTTP 200 response.

**2. Verify database connection**:
```bash
docker-compose logs n8n | grep -i "database\|postgres"
```

**Expected**: Successful migration messages, no connection errors.

**3. Check filesystem mounts**:
```bash
docker-compose exec n8n ls -la /home/node/
```

**Expected**:
- `dropzone/` directory
- `docstore/` directory
- `.n8n/` directory (data)

**4. Browser test**:
- Navigate to https://n8n.local
- Accept certificate warning
- **Expected**: n8n setup page
- Create owner account
- Verify can create workflow

### LiteLLM Proxy

**1. Health check**:
```bash
curl -k https://litellm.local/health/liveliness
```

**Expected**: JSON response with status.

**2. Database connection**:
```bash
docker-compose logs litellm | grep -i "database"
```

**Expected**: Connection successful.

**3. Browser test**:
- Navigate to https://litellm.local
- Login with credentials from `.env`:
  - Username: `admin` (or custom)
  - Password: `LITELLM_UI_PASSWORD` value
- **Expected**: LiteLLM dashboard loads

### Traefik Reverse Proxy

**1. Dashboard access**:
- Navigate to https://traefik.local
- **Expected**: Traefik dashboard showing all routers (Traefik runs in `coreservices-homelab`)

**2. Verify all routes**:
Check dashboard shows routers for:
- open-webui
- n8n
- litellm
- searxng
- ollama
- mcpo

**3. SSL certificate check**:
```bash
openssl s_client -connect open-webui.local:443 -showcerts < /dev/null 2>/dev/null | openssl x509 -noout -text | grep "Subject:"
```

**Expected**: Certificate details (self-signed is OK).

**4. Core-service health check**:
```bash
cd ../coreservices-homelab
docker-compose ps traefik
```

### Redis Cache

**1. Connection test**:
```bash
docker-compose exec redis redis-cli -a "${REDIS_PASSWORD}" ping
```

**Expected**: `PONG`

**2. Memory check**:
```bash
docker-compose exec redis redis-cli -a "${REDIS_PASSWORD}" INFO memory | grep used_memory_human
```

**Expected**: Shows memory usage (should be low initially).

### SearXNG Web Search

**1. Health check**:
```bash
curl -k https://searxng.local/healthz
```

**Expected**: HTTP 200 response.

**2. Test search functionality**:
```bash
curl -k "https://searxng.local/search?q=test&format=json" | jq '.results | length'
```

**Expected**: Returns number of search results (should be > 0).

**3. Browser test**:
- Navigate to https://searxng.local
- Enter test search query
- **Expected**: Search results from multiple engines displayed

**4. Verify Open WebUI integration**:
```bash
docker-compose exec open-webui env | grep -i search
```

**Expected output**:
```
ENABLE_RAG_WEB_SEARCH=true
RAG_WEB_SEARCH_ENGINE=searxng
SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
```

**5. Test internal connectivity**:
```bash
docker-compose exec open-webui curl -s "http://searxng:8080/search?q=docker&format=json" | head -c 100
```

**Expected**: JSON response with search results.

## Integration Testing

### End-to-End Workflow Test

**Scenario**: Use Open WebUI to chat with Ollama model.

**Steps**:
1. Navigate to https://open-webui.local
2. Select `llama3.2:3b` model
3. Send message: "What is 2+2?"
4. **Expected**: Model responds with "4" or explanation

**Validates**:
- Traefik routing works
- Open WebUI loads correctly
- Open WebUI → Ollama communication works
- Ollama model loads and infers
- Database stores conversation
- SSL certificates accepted

### File Access Test

**Scenario**: Verify Open WebUI can access host filesystem.

**Steps**:
1. Create test file on host:
```bash
echo "Test content" > ~/Downloads/ai-stack-test.txt
```

2. In Open WebUI chat, reference file:
   "Read the file at /mnt/host/downloads/ai-stack-test.txt"

3. **Expected**: Model/AI can access and read file content

4. Cleanup:
```bash
rm ~/Downloads/ai-stack-test.txt
```

### Web Search Integration Test

**Scenario**: Verify Open WebUI can perform web searches via SearXNG.

**Steps**:
1. Navigate to https://open-webui.local
2. Enable web search in conversation (look for search toggle/option)
3. Ask question requiring current information:
   "What is the current weather in London?"
   or
   "Search the web for latest Docker Compose features"

4. **Expected**:
   - Open WebUI queries SearXNG
   - SearXNG returns aggregated search results
   - AI incorporates web data in response
   - Response indicates it used web search results

**Validates**:
- Traefik routing works for SearXNG
- Open WebUI → SearXNG communication functional
- SearXNG can reach external search engines
- RAG web search feature enabled and working
- AI model can process and synthesize web data

### n8n to Database Test

**Scenario**: Verify n8n can execute database queries.

**Steps**:
1. In n8n (https://n8n.local), create new workflow
2. Add Postgres node
3. Configure connection:
   - Host: `postgresql`
   - Database: `n8n_db`
   - User: value from `.env` (`POSTGRES_USER`)
   - Password: value from `.env` (`POSTGRES_PASSWORD`)
4. Execute query: `SELECT version();`
5. **Expected**: Returns PostgreSQL version

## Performance Testing

### Resource Usage Check

```bash
docker stats --no-stream
```

**Expected**:
- No service using 100% CPU continuously
- Memory usage within configured limits
- No services restarting repeatedly

**Typical Usage** (idle):
- Ollama: 500MB-2GB (with models loaded)
- PostgreSQL: 200-500MB
- n8n: 500MB-1GB
- Open WebUI: 200-500MB
- Others: < 200MB each

### Response Time Test

**Ollama inference time**:
```bash
time docker exec ollama ollama run llama3.2:3b "Hello"
```

**Expected**: 2-10 seconds (first run slower due to model loading).

**Database query time**:
```bash
time docker-compose exec postgresql psql -U aistack -d aistack_db -c "SELECT 1;"
```

**Expected**: < 100ms

## Security Validation

### 1. Credential Check

```bash
# Verify no hardcoded passwords in compose file
grep -i "password.*:" docker-compose.yml | grep -v "\${" && echo "⚠ Hardcoded password found!" || echo "✓ No hardcoded passwords"
```

**Expected**: "✓ No hardcoded passwords"

### 2. Port Exposure Check

```bash
docker-compose ps --format json | jq '.[].Publishers' | grep "0.0.0.0"
```

**Expected**: Only Traefik ports (80, 443, 8090) exposed to 0.0.0.0.

### 3. Network Isolation Test

**From host, try to access internal service directly**:
```bash
curl http://localhost:5432 2>&1 | grep -q "Connection refused" && echo "✓ PostgreSQL not exposed" || echo "⚠ PostgreSQL exposed to host"
```

**Expected**: Services NOT directly accessible (only via Traefik).

**Exception**: If ports explicitly exposed in compose for debugging, this is expected.

### 4. File Permissions

```bash
ls -la .env
```

**Expected**: File readable only by owner (or limited group), not world-readable.

## Restart and Persistence Test

### 1. Graceful Restart

```bash
# Stop services
docker-compose stop

# Wait a few seconds
sleep 5

# Restart
docker-compose start
```

**Expected**: All services come back healthy.

### 2. Data Persistence Verification

**Before restart**:
- Create a test conversation in Open WebUI
- Note conversation ID or content

**After restart**:
- Access Open WebUI
- **Expected**: Previous conversation still exists

**Database persistence**:
```bash
docker-compose exec postgresql psql -U aistack -d n8n_db -c "SELECT COUNT(*) FROM workflow;"
```

Note the count, restart, check again:
```bash
docker-compose restart postgresql
sleep 10
docker-compose exec postgresql psql -U aistack -d n8n_db -c "SELECT COUNT(*) FROM workflow;"
```

**Expected**: Same count (data persisted).

### 3. Ollama Model Persistence

```bash
# Check models
docker exec ollama ollama list

# Restart Ollama
docker-compose restart ollama
sleep 30

# Check models again
docker exec ollama ollama list
```

**Expected**: Models still present (not re-downloaded).

## Troubleshooting Common Issues

### Service Won't Start

**Check logs**:
```bash
docker-compose logs [service-name] --tail=50
```

**Common causes**:
- Missing environment variable
- Port conflict (something else using 80/443)
- Database connection failure
- Volume permission issues

### Can't Access via Browser

**Check /etc/hosts**:
```bash
cat /etc/hosts | grep "\.local"
```

**Expected**: Entry for all service domains.

**Test DNS resolution**:
```bash
ping -c 1 open-webui.local
```

**Expected**: Resolves to 127.0.0.1

**Check Traefik**:
```bash
docker-compose ps traefik
curl -k https://open-webui.local
```

### Models Not Downloading

**Check Ollama logs**:
```bash
docker logs -f ollama
```

**Common causes**:
- Internet connection issue
- Insufficient disk space
- Ollama service not fully started

**Manual download**:
```bash
docker exec ollama ollama pull llama3.2:3b
```

### Database Connection Errors

**Check PostgreSQL is running**:
```bash
docker-compose exec postgresql pg_isready
```

**Check credentials**:
```bash
# Verify .env has correct values
grep POSTGRES .env
```

**Check service can reach database**:
```bash
docker-compose exec open-webui nc -zv postgresql 5432
```

## Testing Checklist

Use this checklist to track testing progress:

- [ ] docker-compose config validates
- [ ] All environment variables configured
- [ ] All services start successfully
- [ ] All services reach healthy status within 5 minutes
- [ ] PostgreSQL has all required databases
- [ ] pgvector extension enabled on all databases
- [ ] Ollama models download successfully (llama3.2:3b, qwen2.5:7b-instruct, nomic-embed-text)
- [ ] Ollama responds to test inference
- [ ] Open WebUI accessible via browser
- [ ] Open WebUI has all 4 host directories mounted with read-write access
- [ ] Open WebUI connects to Ollama successfully
- [ ] Open WebUI connects to PostgreSQL successfully
- [ ] n8n accessible via browser
- [ ] n8n connects to PostgreSQL successfully
- [ ] n8n has filesystem access (dropzone, docstore)
- [ ] LiteLLM accessible and connects to database
- [ ] SearXNG accessible via browser
- [ ] SearXNG returns search results
- [ ] SearXNG integrates with Open WebUI
- [ ] Open WebUI RAG web search enabled
- [ ] Traefik dashboard accessible
- [ ] Traefik routes all services correctly (including SearXNG)
- [ ] All services accessible via HTTPS with self-signed certs
- [ ] Services accessible from other devices on LAN
- [ ] Services communicate internally via Docker network
- [ ] Internal services NOT directly accessible from host
- [ ] No hardcoded credentials in compose file
- [ ] Environment variables properly substituted
- [ ] Data persists across container restarts
- [ ] No critical errors in any service logs
- [ ] Resource usage within acceptable limits
- [ ] End-to-end workflow test passes (Open WebUI → Ollama chat)
- [ ] File access test passes (Open WebUI can read/write host files)
- [ ] Web search integration test passes (Open WebUI → SearXNG → AI response)
- [ ] Setup completes in documented steps (< 5 steps)

## Post-Deployment Validation

After completing all tests, run this command to verify overall health:

```bash
echo "=== Service Status ===" && \
docker-compose ps && \
echo -e "\n=== Resource Usage ===" && \
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" && \
echo -e "\n=== Ollama Models ===" && \
docker exec ollama ollama list && \
echo -e "\n=== Database Status ===" && \
docker-compose exec postgresql pg_isready && \
echo -e "\n✓ All checks complete"
```

## Success Criteria

Your deployment is successful if:

1. ✓ All services show healthy status
2. ✓ All integration tests pass
3. ✓ Zero critical errors in logs
4. ✓ End-to-end workflow completes successfully
5. ✓ Data persists across restarts
6. ✓ Resource usage is stable

---

**Next Steps After Successful Testing**:
- Add custom Open WebUI branding (see configs/open-webui/BRANDING.md)
- Create first n8n workflows
- Configure LiteLLM with external AI providers if needed
- Set up monitoring (Prometheus/Grafana) if desired
- Consider enabling Let's Encrypt for remote access

**Report Issues**: If any test fails, document the failure and check [README.md](README.md) Troubleshooting section.
