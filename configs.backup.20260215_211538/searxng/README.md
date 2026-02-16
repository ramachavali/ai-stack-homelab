# SearXNG Configuration

SearXNG is a privacy-respecting metasearch engine that aggregates results from multiple search providers.

## Overview

**Purpose**: Enables Open WebUI to perform web searches and use real-time internet data in AI responses (RAG - Retrieval Augmented Generation).

**Privacy**:
- Self-hosted - all search queries processed on your infrastructure
- No tracking cookies
- Anonymizes requests to upstream search engines
- No search history logging by default

## Configuration

SearXNG auto-generates its configuration on first startup. The configuration is stored in the `searxng_data` Docker volume.

### Default Search Engines

SearXNG aggregates results from multiple sources:
- Google
- Bing
- DuckDuckGo
- Wikipedia
- Stack Overflow
- GitHub
- And 70+ other engines

### Customization

To customize search engines or settings:

1. **Access SearXNG settings**:
   - Navigate to https://searxng.local
   - Click "Preferences" in top-right
   - Configure enabled engines, categories, etc.

2. **Advanced configuration** (optional):
   ```bash
   # View current config
   docker exec searxng cat /etc/searxng/settings.yml

   # Edit configuration (after container creation)
   docker exec -it searxng vi /etc/searxng/settings.yml

   # Restart to apply changes
   docker-compose restart searxng
   ```

## Environment Variables

Configured in `.env`:

- `SEARXNG_VERSION` - Docker image version (default: `latest`)
- `SEARXNG_SECRET_KEY` - Secret for instance (generate with `openssl rand -hex 16`)
- `SEARXNG_QUERY_URL` - Internal query endpoint for Open WebUI
- `RAG_WEB_SEARCH_ENGINE` - Set to `searxng` for Open WebUI
- `RAG_WEB_SEARCH_RESULT_COUNT` - Number of search results to return (default: 5)

## Usage in Open WebUI

Once configured, Open WebUI can perform web searches:

1. **In conversation**, enable web search:
   - Look for web search toggle in Open WebUI interface
   - Or, ask questions that require current information

2. **Example queries**:
   - "What's the current weather in Paris?"
   - "What are the latest developments in AI?"
   - "Search the web for Docker best practices"

3. **How it works**:
   ```
   Your Question → Open WebUI → SearXNG → [Multiple Search Engines]
                                    ↓
                            Aggregated Results
                                    ↓
                    Ollama AI + Web Context → Response
   ```

## Resource Usage

- **Memory**: ~100-150MB during searches, ~50MB idle
- **CPU**: Minimal when idle, spikes during searches
- **Network**: External requests only when searches performed
- **Disk**: ~50MB for image, ~10MB for config

## Privacy Considerations

**What leaves your network**:
- Search queries (anonymized) to configured search engines
- Requests appear to come from your IP, not individual users

**What stays private**:
- Your conversations with AI
- Which searches you perform (not logged by SearXNG)
- Search result usage (Open WebUI processes locally)

**More private than**:
- Direct Google/Bing searches (no tracking cookies)
- External SearXNG instances (you control the server)
- API-based search (Google Custom Search, Brave API, etc.)

## Troubleshooting

### SearXNG not returning results

**Check service health**:
```bash
docker-compose ps searxng
curl -k https://searxng.local/search?q=test
```

**Check logs**:
```bash
docker-compose logs searxng
```

### Open WebUI not using web search

**Verify configuration**:
```bash
# Check environment variables
docker-compose exec open-webui env | grep -i search
```

**Expected**:
```
ENABLE_RAG_WEB_SEARCH=true
RAG_WEB_SEARCH_ENGINE=searxng
SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>
```

### Rate limiting from search engines

Some search engines may rate limit requests. SearXNG handles this by:
- Using multiple engines simultaneously
- Caching results
- Rotating through available engines

**To reduce rate limiting**:
- Decrease `RAG_WEB_SEARCH_RESULT_COUNT` in `.env`
- Enable fewer search engines in SearXNG preferences

## Security

**Best Practices**:
- Keep `SEARXNG_SECRET_KEY` secure (generate strong random value)
- Use HTTPS (Traefik handles this automatically)
- Don't expose SearXNG directly to internet without authentication
- Review enabled search engines periodically

**Current Setup**:
- SearXNG accessible only via Traefik reverse proxy
- Internal Docker network communication
- Self-signed SSL for local access

## Advanced Configuration

### Custom Search Engines

Edit `/etc/searxng/settings.yml` in container to add custom engines:

```yaml
engines:
  - name: custom_api
    engine: json_engine
    search_url: https://api.example.com/search?q={query}
    # ... additional configuration
```

### Performance Tuning

Adjust in settings.yml:
```yaml
search:
  max_request_timeout: 10.0  # seconds

outgoing:
  max_request_timeout: 10.0
  pool_connections: 100
  pool_maxsize: 20
```

### Disable Specific Engines

In SearXNG web UI or settings.yml:
```yaml
engines:
  - name: google
    disabled: true  # Disable Google
```

## Monitoring

**Check search performance**:
```bash
# View recent searches (if logging enabled)
docker-compose logs searxng --tail=100 | grep "search"

# Check resource usage
docker stats searxng --no-stream
```

**Access SearXNG directly**:
- Navigate to https://searxng.local
- Perform manual searches
- Verify results quality

## Integration with Open WebUI

SearXNG is automatically integrated when `ENABLE_RAG_WEB_SEARCH=true` in Open WebUI configuration.

**Features**:
- Real-time web data in AI responses
- Source attribution (where data came from)
- Combines local AI knowledge + current web information
- Seamless user experience

**When to use**:
- Questions about current events
- Recent product information
- Latest documentation or tutorials
- Time-sensitive data (weather, stock prices, etc.)

**When NOT to use**:
- Private/sensitive conversations
- Questions answerable with local data
- When speed is critical (web search adds latency)

---

**SearXNG is now integrated with your AI Stack!** Web search capabilities are available in Open WebUI for queries requiring current information.
