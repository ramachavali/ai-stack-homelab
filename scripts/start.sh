#!/bin/bash

# =================================================================
# AI Stack Start Script
# Starts services by looping through compose-defined services.
# =================================================================

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

COMPOSE_CMD=(docker-compose)

echo -e "🚀 Starting AI Stack..."
echo "========================"
echo ""

print_step() {
    echo -e "$1"
}

print_success() {
    echo -e "✅ $1"
}

print_warning() {
    echo -e "⚠️ $1"
}

print_error() {
    echo -e "❌ $1"
}

check_core_services_runtime() {
    local core_root="${PROJECT_ROOT}/../coreservices-homelab"
    local running_core_count="0"

    if [ ! -d "$core_root" ]; then
        print_error "Core services folder not found: $core_root"
        echo "  Clone/place coreservices-homelab next to ai-stack-homelab"
        return 1
    fi

    running_core_count="$(cd "$core_root" && docker-compose ps --services --filter status=running | wc -l | tr -d ' ')"
    if [ "$running_core_count" -lt 1 ]; then
        print_error "Core services are not running"
        echo "  Start core services first: cd ../coreservices-homelab && ./scripts/start.sh"
        return 1
    fi

    print_success "Core services are running (${running_core_count} container(s))"
    return 0
}

wait_for_service() {
    local service="$1"
    local timeout="${2:-120}"
    local count=0

    local cid
    cid="$(${COMPOSE_CMD[@]} ps -q "$service" 2>/dev/null || true)"
    if [ -z "$cid" ]; then
        print_error "Unable to resolve container ID for service '$service'"
        return 1
    fi

    echo -n "  Waiting for $service to be ready"
    while [ "$count" -lt "$timeout" ]; do
        local status
        status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo "unknown")"

        if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
            echo -e "\n  ✅ $service is ready"
            return 0
        fi

        if [ "$status" = "unhealthy" ] || [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
            echo -e "\n  ❌ $service failed with status: $status"
            return 1
        fi

        echo -n "."
        sleep 2
        count=$((count + 2))
    done

    echo -e "\n  ❌ $service failed to become ready within ${timeout}s"
    return 1
}

# Check prerequisites
print_step "📋 Checking Prerequisites"

if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running"
    echo ""
    echo "Please start Docker Desktop and try again"
    exit 1
fi
print_success "Docker is running"

if ! docker network inspect core-network > /dev/null 2>&1; then
    print_error "Required Docker network 'core-network' was not found"
    echo ""
    echo "Start core services first:"
    echo "  cd ../coreservices-homelab && ./scripts/start.sh"
    exit 1
fi
print_success "External network 'core-network' is available"

if ! check_core_services_runtime; then
    exit 1
fi

if [ -f ./.rendered.env ]; then
    source ./.rendered.env
else
    print_error ".rendered.env file not found"
    exit 1
fi

print_step "🔍 Validating Configuration"
required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "N8N_ENCRYPTION_KEY" "OPEN_WEBUI_SECRET_KEY" "PICOCLAW_PICO_TOKEN")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ] || [[ "${!var}" == *"your_"* ]] || [[ "${!var}" == *"_here"* ]]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    print_error "Missing or invalid configuration variables:"
    printf '  %s\n' "${missing_vars[@]}"
    echo ""
    echo "Please update your .env file with secure values"
    exit 1
fi
print_success "Configuration validated"

docker_cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo "")"
if [ -n "$docker_cpus" ]; then
    if awk "BEGIN {exit !(${OLLAMA_CPU_LIMIT:-0} > ${docker_cpus})}"; then
        print_warning "OLLAMA_CPU_LIMIT (${OLLAMA_CPU_LIMIT}) exceeds available Docker CPUs (${docker_cpus}); capping to ${docker_cpus}."
        export OLLAMA_CPU_LIMIT="$docker_cpus"
    fi
fi

echo ""
print_step "🚀 Starting Services"

services=()
while IFS= read -r service; do
    services+=("$service")
done < <(${COMPOSE_CMD[@]} config --services)
if [ ${#services[@]} -eq 0 ]; then
    print_error "No services found in compose configuration"
    exit 1
fi

for service in "${services[@]}"; do
    print_step "  ▶ Starting ${service}..."
    ${COMPOSE_CMD[@]} up -d "$service"
done

print_step "🏥 Waiting for service readiness"
for service in "${services[@]}"; do
    wait_for_service "$service" 180
done

print_step "🔍 Post-start checks"
if ! docker exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1 FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | grep -q "1"; then
    print_warning "pgvector extension not found"
    echo "  💡 You can install it later with: ./scripts/install-pgvector.sh"
fi

if ! docker exec ollama ollama list | tail -n +2 | grep -q .; then
    print_warning "No AI models found in Ollama"
    echo "  📥 You can pull models with: docker exec ollama ollama pull [model_name]"
fi

echo ""
print_success "AI Stack Started Successfully"
echo ""
echo -e "📊 n8n:        https://n8n.local"
echo -e "🤖 Open WebUI: https://open-webui.local"
echo -e "🎯 LiteLLM:    https://litellm.local"
echo -e "🧠 Ollama:     https://ollama.local"
echo -e "🔗 MCPO:       https://mcpo.local"
echo -e "🔎 SearXNG:    https://searxng.local"
echo -e "🧭 AI Portal:  https://portal.local"
echo -e "🦐 PicoClaw:   https://picoclaw.local/health"
