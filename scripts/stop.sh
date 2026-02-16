#!/bin/bash

# =================================================================
# AI Stack Stop Script
# =================================================================

set -o errexit
set -o nounset

#set -x

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Load environment variables
if [ -f ./.rendered.env ]; then
    source ./.rendered.env
else
    echo -e "❌ .env file not found"
    exit 1
fi

echo -e "🛑 Stopping AI Stack..."
echo "======================"

# Parse command line arguments
FORCE_STOP=false
REMOVE_VOLUMES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_STOP=true
            shift
            ;;
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --force, -f     Force stop containers (kill instead of graceful stop)"
            echo "  --volumes, -v   Remove volumes (WARNING: This will delete all data)"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${RED}⚠️  WARNING: You are about to remove all volumes and data!${NC}"
    echo "This action cannot be undone."
    read -p "Are you sure? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Stop services gracefully or forcefully
if [ "$FORCE_STOP" = true ]; then
    echo -e "⚡ Force stopping all services..."
    docker-compose kill
else
    echo -e "🔄 Gracefully stopping all services..."
    
    # Stop services in reverse dependency order
    echo -e "🔗 Stopping MCP services..."
    docker-compose stop mcpo n8n-mcp
    
    echo -e "🌐 Stopping Open WebUI..."
    docker-compose stop open-webui
    
    echo -e "🎯 Stopping LiteLLM..."
    docker-compose stop litellm
    
    echo -e "🔄 Stopping n8n..."
    docker-compose stop n8n
    
    echo -e "🤖 Stopping Ollama..."
    docker-compose stop ollama
    
    echo -e "🔴 Stopping Redis..."
    docker-compose stop redis
    
    echo -e "🐘 Stopping PostgreSQL..."
    docker-compose stop postgresql

fi

echo -e "🧹 Removing containers..."
docker-compose down

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "🗑️  Removing volumes..."
    docker-compose down -v
    echo -e "💀 All data has been removed!"
fi

# Clean up unused resources
echo -e "🧽 Cleaning up unused Docker resources..."
docker system prune -f

# Show final status
echo ""
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "🏁 AI Stack stopped and all data removed"
    echo "To start fresh, run: ./scripts/setup.sh"
else
    echo -e "🏁 AI Stack stopped successfully"
    echo "Data is preserved. To restart, run: ./scripts/start.sh"
fi

echo ""
echo "Other useful commands:"
echo "  docker-compose ps              # Check service status"
echo "  docker-compose logs [service]  # View service logs"
echo "  docker system df               # Check Docker disk usage"
