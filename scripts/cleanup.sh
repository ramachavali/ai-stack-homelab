#!/bin/bash

set -o errexit
set -o nounset

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -f ./.rendered.env ]; then
    source ./.rendered.env
elif [ -f ./.env ]; then
    source ./.env
else
    echo -e "⚠️  .rendered.env/.env not found; continuing cleanup without loaded env vars"
fi

echo "🧹 AI stack cleanup"

read -p "Do you want to proceed with cleanup? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Stopping AI stack..."
docker-compose down --remove-orphans || true

safe_remove() {
    local path="${1}"
    local description="${2}"
    
    if [ -e "$path" ]; then
        echo -e "  ⚠️  Removing: $description"
        rm -rf "$path"
        echo -e "  ✅ Removed: $path"
    else
        echo -e "  ℹ️  Not found (already clean): $path"
    fi
}

echo "Removing deprecated files..."
safe_remove "docs/postgresql-17.5-migration-guide.md" "PostgreSQL 17.5 migration guide"
safe_remove "docs/postgresql-migration-guide.md" "PostgreSQL migration guide"
safe_remove "docs/script-updates-summary.md" "Script updates summary"
safe_remove "docs/service-name-change-summary.md" "Service name change summary"
safe_remove "docs/vector-database-guide.md" "Vector database guide"

safe_remove ".env.prod" "Redundant production environment file"

echo "Removing temporary/system files..."
find . -name ".DS_Store" -type f -delete 2>/dev/null || true

echo "Removing unused config and data paths..."
safe_remove "configs/litellm" "Unused LiteLLM config directory"
safe_remove "configs/nginx" "Unused Nginx config directory"
safe_remove "logs/nginx" "Unused Nginx logs directory"
safe_remove "configs/n8n/.gitkeep" "n8n .gitkeep file"
safe_remove "configs/ollama/.gitkeep" "Ollama .gitkeep file"
safe_remove "data/open-webui" "Redundant open-webui data directory"
safe_remove "configs/postgres/init/00-install-extensions.sql" "Outdated PostgreSQL extension script"

echo "Removing env files..."
safe_remove "./.env" "remove .env file"
safe_remove "./.rendered.env" "remove .env file"

remove_docker_volume() {
    local volume="${1}"

    if docker volume inspect "$volume" >/dev/null 2>&1; then
        if docker volume rm "$volume" >/dev/null 2>&1; then
            echo -e "  ✅ Removed volume: $volume"
        else
            echo -e "  ⚠️  Skipped volume (in use): $volume"
        fi
    else
        echo -e "  ℹ️  Volume not found: $volume"
    fi
}

echo "Removing docker volumes..."
compose_volumes=()
while IFS= read -r volume; do
    compose_volumes+=("$volume")
done < <(docker-compose config --volumes 2>/dev/null | sed '/^$/d' | sort -u)

if [ "${#compose_volumes[@]}" -gt 0 ]; then
    for volume in "${compose_volumes[@]}"; do
        remove_docker_volume "$volume"
    done
else
    echo -e "  ⚠️  Could not resolve compose volumes; using fallback volume list"
    for volume in postgres_data redis_data ollama_data n8n_data open_webui_data litellm_data mcp_data searxng_data picoclaw_data; do
        remove_docker_volume "$volume"
    done
fi

echo "Pruning images..."
docker image prune -f 2>/dev/null || true

echo "Pruning docker system..."
docker system prune -f 2>/dev/null || true

echo ""
read -p "Remove VS Code workspace file? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_remove "ai-stack.code-workspace" "VS Code workspace file"
fi

echo "Removing empty directories..."
find . -type d -empty -not -path "./.git/*" -delete 2>/dev/null || true
echo "Cleanup completed."