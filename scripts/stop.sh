#!/bin/bash

# =================================================================
# AI Stack Stop Script
# Stops services by looping through compose-defined services in reverse order.
# =================================================================

set -o errexit
set -o nounset
set -o pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

COMPOSE_CMD=(docker-compose --profile picoclaw)

echo -e "🛑 Stopping AI Stack..."
echo "======================"

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
            echo -e "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "⚠️  WARNING: You are about to remove all volumes and data!"
    echo "This action cannot be undone."
    read -p "Are you sure? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

if [ "$FORCE_STOP" = true ]; then
    echo -e "⚡ Force stopping all services..."
    ${COMPOSE_CMD[@]} kill
else
    echo -e "🔄 Gracefully stopping all services..."

    mapfile -t services < <(${COMPOSE_CMD[@]} config --services)
    if [ ${#services[@]} -eq 0 ]; then
        echo -e "⚠️ No services found in compose configuration"
    else
        for (( idx=${#services[@]}-1; idx>=0; idx-- )); do
            service="${services[$idx]}"
            echo -e "  ⏹ Stopping ${service}..."
            ${COMPOSE_CMD[@]} stop "$service" || true
        done
    fi
fi

echo -e "🧹 Removing containers..."
${COMPOSE_CMD[@]} down

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "🗑️  Removing volumes..."
    ${COMPOSE_CMD[@]} down -v
    echo -e "💀 All data has been removed!"
fi

echo -e "🧽 Cleaning up unused Docker resources..."
docker system prune -f

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
echo "  docker-compose --profile picoclaw ps              # Check service status"
echo "  docker-compose --profile picoclaw logs [service]  # View service logs"
echo "  docker system df                                   # Check Docker disk usage"
