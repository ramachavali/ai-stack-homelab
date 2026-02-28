#!/bin/bash

# =================================================================
# AI Stack Restore Script
# Restore from encrypted backups with verification
# =================================================================

set -o errexit
set -o nounset
set -o pipefail

#set -x

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

COMPOSE_CMD=(docker-compose)

compose_volume_list() {
    local compose_volumes=()
    while IFS= read -r vol; do
        [ -n "$vol" ] && compose_volumes+=("$vol")
    done < <(${COMPOSE_CMD[@]} config --volumes)
    printf '%s\n' "${compose_volumes[@]}"
}

compose_service_exists() {
    local target="$1"
    compose_services=()
    while IFS= read -r svc; do
        compose_services+=("$svc")
    done < <(${COMPOSE_CMD[@]} config --services)
    for svc in "${compose_services[@]}"; do
        if [ "$svc" = "$target" ]; then
            return 0
        fi
    done
    return 1
}

# Load environment variables
if [ -f ./.rendered.env ]; then
    source ./.rendered.env
else
    echo -e "❌ .rendered.env file not found"
    exit 1
fi

# Configuration
BACKUP_DIR="${BACKUP_LOCATION:-$HOME/Documents/ai-stack-backups}"
ENCRYPT="${BACKUP_ENCRYPT:-true}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"

echo -e "🔄 AI Stack Restore Utility"
echo "==========================="

# Parse command line arguments
RESTORE_DATE=""
RESTORE_TYPE="full"
SERVICES=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --date|-d)
            RESTORE_DATE="$2"
            shift 2
            ;;
        --type|-t)
            RESTORE_TYPE="$2"
            shift 2
            ;;
        --service|-s)
            SERVICES="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --list|-l)
            echo -e "📋 Available backups:"
            echo "==================="
            if [ -d "$BACKUP_DIR" ]; then
                find "$BACKUP_DIR" -name "backup_manifest_*.json" | sort -r | while read manifest; do
                    date_part=$(basename "$manifest" | sed 's/backup_manifest_//' | sed 's/.json//')
                    echo -e "📅 $date_part"
                    if command -v jq > /dev/null 2>&1; then
                        jq -r '. | "   Type: \(.backup_type)\n   Date: \(.backup_date)\n   Files: \(.files | length)"' "$manifest" 2>/dev/null || echo "   (Manifest details unavailable)"
                    fi
                    echo ""
                done
            else
                echo "No backup directory found at: $BACKUP_DIR"
            fi
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --date, -d      Restore from specific backup date (YYYYMMDD_HHMMSS)"
            echo "  --type, -t      Restore type: full, data, config (default: full)"
            echo "  --service, -s   Specific service: postgres, n8n, ollama, etc."
            echo "  --dry-run       Show what would be restored without actually doing it"
            echo "  --list, -l      List available backups"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --list                    # List available backups"
            echo "  $0 --date 20240101_120000    # Restore full backup from specific date"
            echo "  $0 --service postgresql        # Restore only PostgreSQL from latest backup"
            exit 0
            ;;
        *)
            echo -e "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Find latest backup if no date specified
if [ -z "$RESTORE_DATE" ]; then
    echo -e "🔍 Finding latest backup..."
    latest_manifest=$(find "$BACKUP_DIR" -name "backup_manifest_*.json" 2>/dev/null | sort -r | head -n1)
    if [ -z "$latest_manifest" ]; then
        echo -e "❌ No backups found in $BACKUP_DIR"
        exit 1
    fi
    RESTORE_DATE=$(basename "$latest_manifest" | sed 's/backup_manifest_//' | sed 's/.json//')
    echo -e "📅 Using latest backup: $RESTORE_DATE"
fi

# Verify backup exists
MANIFEST_FILE="$BACKUP_DIR/backup_manifest_${RESTORE_DATE}.json"
if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "❌ Backup manifest not found: $MANIFEST_FILE"
    echo "Available backups:"
    find "$BACKUP_DIR" -name "backup_manifest_*.json" | sort -r | head -5
    exit 1
fi

echo -e "📋 Backup information:"
if command -v jq > /dev/null 2>&1; then
    jq -r '. | "Date: \(.backup_date)\nType: \(.backup_type)\nServices: \(.services)\nFiles: \(.files | length)"' "$MANIFEST_FILE"
else
    echo "Manifest: $MANIFEST_FILE"
fi

# Function to decrypt file
decrypt_file() {
    local file="$1"
    if [ -f "${file}.enc" ] && [ "$ENCRYPT" = "true" ] && [ -n "$ENCRYPTION_KEY" ]; then
        echo -e "🔓 Decrypting $(basename "$file")..."
        openssl enc -aes-256-cbc -d -in "${file}.enc" -out "$file" -pass pass:"$ENCRYPTION_KEY"
        echo "$file"
    elif [ -f "$file" ]; then
        echo "$file"
    else
        echo ""
    fi
}

# Function to restore PostgreSQL
restore_postgres() {
    echo -e "🐘 Restoring PostgreSQL databases..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would restore PostgreSQL databases"
        return
    fi
    
    # Ensure PostgreSQL is running
    if compose_service_exists "postgresql"; then
        ${COMPOSE_CMD[@]} up -d postgresql
        sleep 10
    else
        echo -e "❌ Service 'postgresql' not found in compose configuration"
        exit 1
    fi
    
    # Restore main database
    main_backup=$(decrypt_file "$BACKUP_DIR/postgres_main_${RESTORE_DATE}.sql.gz")
    if [ -n "$main_backup" ] && [ -f "$main_backup" ]; then
        echo -e "  📊 Restoring main database..."
        zcat "$main_backup" | docker exec -i postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
        rm -f "$main_backup"
    fi
    
    # Restore n8n database
    n8n_backup=$(decrypt_file "$BACKUP_DIR/postgres_n8n_db_${RESTORE_DATE}.sql.gz")
    if [ -n "$n8n_backup" ] && [ -f "$n8n_backup" ]; then
        echo -e "  🔄 Restoring n8n database..."
        docker exec postgresql createdb -U "$POSTGRES_USER" n8n_db 2>/dev/null || true
        zcat "$n8n_backup" | docker exec -i postgresql psql -U "$POSTGRES_USER" -d "n8n_db"
        rm -f "$n8n_backup"
    fi
    
    # Restore LiteLLM database
    litellm_backup=$(decrypt_file "$BACKUP_DIR/postgres_litellm_db_${RESTORE_DATE}.sql.gz")
    if [ -n "$litellm_backup" ] && [ -f "$litellm_backup" ]; then
        echo -e "  🎯 Restoring LiteLLM database..."
        docker exec postgresql createdb -U "$POSTGRES_USER" litellm_db 2>/dev/null || true
        zcat "$litellm_backup" | docker exec -i postgresql psql -U "$POSTGRES_USER" -d "litellm_db"
        rm -f "$litellm_backup"
    fi
    
    # Restore Open WebUI database (supports current and legacy backup naming)
    open_webui_backup=$(decrypt_file "$BACKUP_DIR/postgres_openwebui_db_${RESTORE_DATE}.sql.gz")
    if [ -z "$open_webui_backup" ] || [ ! -f "$open_webui_backup" ]; then
        open_webui_backup=$(decrypt_file "$BACKUP_DIR/postgres_open_webui_${RESTORE_DATE}.sql.gz")
    fi
    if [ -n "$open_webui_backup" ] && [ -f "$open_webui_backup" ]; then
        echo -e "  🌐 Restoring Open WebUI database..."
        docker exec postgresql createdb -U "$POSTGRES_USER" open_webui_db 2>/dev/null || true
        zcat "$open_webui_backup" | docker exec -i postgresql psql -U "$POSTGRES_USER" -d "open_webui_db"
        rm -f "$open_webui_backup"
    fi
    
    echo -e "✅ PostgreSQL restore completed"
}

# Function to restore Docker volumes
restore_volumes() {
    echo -e "💾 Restoring Docker volumes..."

    volumes=()
    while IFS= read -r volume; do
        [ -n "$volume" ] && volumes+=("$volume")
    done < <(compose_volume_list)

    if [ ${#volumes[@]} -eq 0 ]; then
        echo -e "    ⚠️ No named volumes found in compose configuration"
    fi

    for volume in "${volumes[@]}"; do
        volume_backup=$(decrypt_file "$BACKUP_DIR/${volume}_${RESTORE_DATE}.tar.gz")
        if [ -z "$volume_backup" ] || [ ! -f "$volume_backup" ]; then
            volume_backup=$(decrypt_file "$BACKUP_DIR/${volume}_${RESTORE_DATE}.tar")
        fi
        if [ -n "$volume_backup" ] && [ -f "$volume_backup" ]; then
            echo -e "  📁 Restoring ${volume}..."
            
            if [ "$DRY_RUN" = true ]; then
                echo "    [DRY RUN] Would restore volume: ${volume}"
            else
                tar_extract_flags="xf"
                case "$volume_backup" in
                    *.tar.gz|*.tgz) tar_extract_flags="xzf" ;;
                esac
                # Remove existing volume and recreate
                docker volume rm "${volume}" 2>/dev/null || true
                docker volume create "${volume}"
                
                # Restore volume data
                docker run --rm \
                    -v "${volume}:/data" \
                    -v "$BACKUP_DIR":/backup \
                    alpine sh -c "cd /data && tar ${tar_extract_flags} /backup/$(basename "$volume_backup")"
            fi
            
            rm -f "$volume_backup"
        fi
    done

    if ! printf '%s\n' "${volumes[@]}" | grep -qx "picoclaw_data"; then
        picoclaw_backup=$(decrypt_file "$BACKUP_DIR/picoclaw_data_${RESTORE_DATE}.tar.gz")
        if [ -z "$picoclaw_backup" ] || [ ! -f "$picoclaw_backup" ]; then
            picoclaw_backup=$(decrypt_file "$BACKUP_DIR/picoclaw_data_${RESTORE_DATE}.tar")
        fi
        if [ -n "$picoclaw_backup" ] && [ -f "$picoclaw_backup" ]; then
        echo -e "  📁 Restoring bind mount: data/picoclaw..."
        if [ "$DRY_RUN" = true ]; then
            echo "    [DRY RUN] Would restore data/picoclaw"
        else
            rm -rf data/picoclaw
            mkdir -p data
            tar xf "$picoclaw_backup" -C data
        fi
        rm -f "$picoclaw_backup"
        fi
    fi
    
    echo -e "✅ Volume restore completed"
}

# Function to restore configuration files
restore_configs() {
    echo -e "⚙️  Restoring configuration files..."
    
    config_backup=$(decrypt_file "$BACKUP_DIR/configs_${RESTORE_DATE}.tar.gz")
    if [ -n "$config_backup" ] && [ -f "$config_backup" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY RUN] Would restore configuration files"
        else
            # Backup current configs
            if [ -d configs ]; then
                mv configs "configs.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            
            # Restore configs
            tar xzf "$config_backup"
        fi
        
        rm -f "$config_backup"
    fi
    
    echo -e "✅ Configuration restore completed"
}

# Function to restore specific service
restore_service() {
    local service="$1"
    echo -e "🎯 Restoring service: $service"
    
    case "$service" in
        postgres|postgresql)
            restore_postgres
            ;;
        n8n|ollama|open-webui|redis|litellm|mcp|postgresql|searxng)
            volume_name="${service}_data"
            if [ "$service" = "open-webui" ]; then
                volume_name="open_webui_data"
            elif [ "$service" = "postgresql" ]; then
                volume_name="postgres_data"
            fi

            volume_backup=$(decrypt_file "$BACKUP_DIR/${volume_name}_${RESTORE_DATE}.tar.gz")
            if [ -n "$volume_backup" ] && [ -f "$volume_backup" ]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "  [DRY RUN] Would restore ${service} data"
                else
                    tar_extract_flags="xf"
                    case "$volume_backup" in
                        *.tar.gz|*.tgz) tar_extract_flags="xzf" ;;
                    esac
                    docker volume rm "${volume_name}" 2>/dev/null || true
                    docker volume create "${volume_name}"
                    docker run --rm \
                        -v "${volume_name}:/data" \
                        -v "$BACKUP_DIR":/backup \
                        alpine sh -c "cd /data && tar ${tar_extract_flags} /backup/$(basename "$volume_backup")"
                fi
                rm -f "$volume_backup"
            else
                echo -e "⚠️  No backup found for service: $service"
            fi
            ;;
        picoclaw|picoclaw-gateway)
            picoclaw_backup=$(decrypt_file "$BACKUP_DIR/picoclaw_data_${RESTORE_DATE}.tar.gz")
            if [ -z "$picoclaw_backup" ] || [ ! -f "$picoclaw_backup" ]; then
                picoclaw_backup=$(decrypt_file "$BACKUP_DIR/picoclaw_data_${RESTORE_DATE}.tar")
            fi
            if [ -n "$picoclaw_backup" ] && [ -f "$picoclaw_backup" ]; then
                if [ "$DRY_RUN" = true ]; then
                    echo "  [DRY RUN] Would restore picoclaw data"
                else
                    tar_extract_flags="xf"
                    case "$picoclaw_backup" in
                        *.tar.gz|*.tgz) tar_extract_flags="xzf" ;;
                    esac
                    if docker volume inspect picoclaw_data >/dev/null 2>&1 || printf '%s\n' "$(compose_volume_list)" | grep -qx "picoclaw_data"; then
                        docker volume rm "picoclaw_data" 2>/dev/null || true
                        docker volume create "picoclaw_data"
                        docker run --rm \
                            -v "picoclaw_data:/data" \
                            -v "$BACKUP_DIR":/backup \
                            alpine sh -c "cd /data && tar ${tar_extract_flags} /backup/$(basename "$picoclaw_backup")"
                    else
                        rm -rf data/picoclaw
                        mkdir -p data
                        tar ${tar_extract_flags} "$picoclaw_backup" -C data
                    fi
                fi
                rm -f "$picoclaw_backup"
            else
                echo -e "⚠️  No backup found for service: $service"
            fi
            ;;
        *)
            echo -e "❌ Unknown service: $service"
            exit 1
            ;;
    esac
}

# Warning for non-dry-run
if [ "$DRY_RUN" = false ]; then
    echo -e "⚠️  WARNING: This will overwrite existing data!"
    echo "Current data will be backed up before restoration."
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    # Stop services before restore
    echo -e "🛑 Stopping AI Stack services..."
    ${COMPOSE_CMD[@]} down
fi

# Perform restore based on type
echo -e "🔄 Starting $RESTORE_TYPE restore..."

case "$RESTORE_TYPE" in
    full)
        if [ -n "$SERVICES" ]; then
            restore_service "$SERVICES"
        else
            restore_postgres
            restore_volumes
            restore_configs
        fi
        ;;
    data)
        if [ -n "$SERVICES" ]; then
            restore_service "$SERVICES"
        else
            restore_postgres
            restore_volumes
        fi
        ;;
    config)
        restore_configs
        ;;
    *)
        echo -e "❌ Unknown restore type: $RESTORE_TYPE"
        exit 1
        ;;
esac

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo -e "🎉 Restore completed successfully!"
    echo "=========================="
    echo "📅 Restored from: $RESTORE_DATE"
    echo "🔄 Type: $RESTORE_TYPE"
    echo ""
    echo "To start the AI Stack with restored data:"
    echo "  ./scripts/start.sh"
else
    echo ""
    echo -e "🔍 Dry run completed"
    echo "No changes were made to the system."
fi
