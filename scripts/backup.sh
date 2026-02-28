#!/bin/bash

# =================================================================
# AI Stack Backup Script
# Simple, comprehensive backup for all AI Stack data
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


echo -e "💾 AI Stack Backup Utility"
echo "============================"
echo ""

# Configuration
BACKUP_DIR="${BACKUP_LOCATION:-$HOME/Documents/ai-stack-backups}"
DATE=$(date +%Y%m%d_%H%M%S)
ENCRYPT="${BACKUP_ENCRYPT:-true}"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
POSTGRES_ADDITIONAL_DBS="${POSTGRES_ADDITIONAL_DBS:-}"

# Parse command line arguments
BACKUP_TYPE="full"
SERVICES=""
COMPRESS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --type|-t)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        --service|-s)
            SERVICES="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --type, -t       Backup type: full, data, config (default: full)"
            echo "  --service, -s    Specific service: postgres, n8n, ollama, etc."
            echo "  --no-compress    Skip compression (faster, larger files)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                       # Full backup"
            echo "  $0 --type data           # Data only backup"
            echo "  $0 --service postgresql   # PostgreSQL only"
            exit 0
            ;;
        *)
            echo -e "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to encrypt file if encryption is enabled
encrypt_file() {
    local file="$1"
    if [ "$ENCRYPT" = "true" ] && [ -n "$ENCRYPTION_KEY" ]; then
        echo -e "🔒 Encrypting $(basename "$file")..."
        openssl enc -aes-256-cbc -in "$file" -out "${file}.enc" -pass pass:"$ENCRYPTION_KEY"
        rm "$file"
        echo "${file}.enc"
    else
        echo "$file"
    fi
}

# Function to check if services are running
check_services() {
    echo -e "🔍 Checking service status..."

    if compose_service_exists "postgresql" && ! ${COMPOSE_CMD[@]} ps --services --filter "status=running" | grep -q "^postgresql$"; then
        echo -e "⚠️ PostgreSQL is not running. Some backups may be incomplete."
    else
        echo -e "✅ PostgreSQL is running"
    fi
    
    echo ""
}

# Function to create backup directory
setup_backup_dir() {
    echo -e "📁 Setting up backup directory..."
    mkdir -p "$BACKUP_DIR"
    echo -e "✅ Backup directory: $BACKUP_DIR"
    echo ""
}

# Function to backup PostgreSQL databases
backup_postgres() {
    echo -e "🐘 Backing up PostgreSQL databases..."
    
    # Backup main database
    echo "  📊 Backing up main database..."
    if [ "$COMPRESS" = true ]; then
        docker exec postgresql pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$BACKUP_DIR/postgres_main_${DATE}.sql.gz"
        encrypt_file "$BACKUP_DIR/postgres_main_${DATE}.sql.gz"
    else
        docker exec postgresql pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_DIR/postgres_main_${DATE}.sql"
        encrypt_file "$BACKUP_DIR/postgres_main_${DATE}.sql"
    fi
    
    # Backup additional databases
    if [ -n "${POSTGRES_ADDITIONAL_DBS}" ]; then
        IFS=',' read -ra DBS <<< "${POSTGRES_ADDITIONAL_DBS}"
        for db in "${DBS[@]}"; do
            db=$(echo "$db" | xargs) # trim whitespace
            echo "  📊 Backing up database: $db..."
            if docker exec postgresql psql -U "$POSTGRES_USER" -lqt | cut -d \| -f 1 | grep -qw "$db"; then
                if [ "$COMPRESS" = true ]; then
                    docker exec postgresql pg_dump -U "$POSTGRES_USER" "$db" | gzip > "$BACKUP_DIR/postgres_${db}_${DATE}.sql.gz"
                    encrypt_file "$BACKUP_DIR/postgres_${db}_${DATE}.sql.gz"
                else
                    docker exec postgresql pg_dump -U "$POSTGRES_USER" "$db" > "$BACKUP_DIR/postgres_${db}_${DATE}.sql"
                    encrypt_file "$BACKUP_DIR/postgres_${db}_${DATE}.sql"
                fi
            else
                echo -e "    ⚠️ Database $db not found, skipping"
            fi
        done
    fi
    
    echo -e "✅ PostgreSQL backup completed"
}

# Function to backup Docker volumes
backup_volumes() {
    echo -e "💾 Backing up Docker volumes..."

    volumes=()
    while IFS= read -r volume; do
        [ -n "$volume" ] && volumes+=("$volume")
    done < <(compose_volume_list)

    if [ ${#volumes[@]} -eq 0 ]; then
        echo -e "    ⚠️ No named volumes found in compose configuration"
    fi

    for volume in "${volumes[@]}"; do
        echo "  📁 Backing up volume: $volume..."
        if docker volume inspect "$volume" > /dev/null 2>&1; then
            if [ "$COMPRESS" = true ]; then
                docker run --rm \
                    -v "$volume:/data" \
                    -v "$BACKUP_DIR":/backup \
                    alpine tar czf "/backup/${volume}_${DATE}.tar.gz" -C /data .
                encrypt_file "$BACKUP_DIR/${volume}_${DATE}.tar.gz"
            else
                docker run --rm \
                    -v "$volume:/data" \
                    -v "$BACKUP_DIR":/backup \
                    alpine tar cf "/backup/${volume}_${DATE}.tar" -C /data .
                encrypt_file "$BACKUP_DIR/${volume}_${DATE}.tar"
            fi
        else
            echo -e "    ⚠️ Volume $volume not found, skipping"
        fi
    done

    if ! printf '%s\n' "${volumes[@]}" | grep -qx "picoclaw_data" && [ -d "data/picoclaw" ]; then
        echo "  📁 Backing up bind mount: data/picoclaw..."
        if [ "$COMPRESS" = true ]; then
            tar czf "$BACKUP_DIR/picoclaw_data_${DATE}.tar.gz" -C data picoclaw
            encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar.gz"
        else
            tar cf "$BACKUP_DIR/picoclaw_data_${DATE}.tar" -C data picoclaw
            encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar"
        fi
    else
        echo -e "    ⚠️ data/picoclaw not found, skipping"
    fi
    
    echo -e "✅ Volume backup completed"
}

# Function to backup configuration files
backup_configs() {
    echo -e "⚙️ Backing up configuration files..."
    
    if [ -d configs ]; then
        echo "  📋 Backing up configs directory..."
        if [ "$COMPRESS" = true ]; then
            tar czf "$BACKUP_DIR/configs_${DATE}.tar.gz" configs/
            encrypt_file "$BACKUP_DIR/configs_${DATE}.tar.gz"
        else
            tar cf "$BACKUP_DIR/configs_${DATE}.tar" configs/
            encrypt_file "$BACKUP_DIR/configs_${DATE}.tar"
        fi
    fi
    
    # Backup important root files (excluding .env for security)
    echo "  📋 Backing up docker-compose.yml..."
    cp docker-compose.yml "$BACKUP_DIR/docker-compose_${DATE}.yml"
    encrypt_file "$BACKUP_DIR/docker-compose_${DATE}.yml"
    
    echo -e "✅ Configuration backup completed"
}

# Function to backup specific service
backup_service() {
    local service="$1"
    echo -e "🎯 Backing up service: $service"
    
    case "$service" in
        postgres|postgresql)
            backup_postgres
            ;;
        n8n|ollama|open-webui|redis|litellm|mcp|postgresql|searxng)
            echo "  💾 Backing up ${service} data..."
            volume_name="${service}_data"
            if [ "$service" = "open-webui" ]; then
                volume_name="open_webui_data"
            elif [ "$service" = "postgresql" ]; then
                volume_name="postgres_data"
            fi
            
            if docker volume inspect "$volume_name" > /dev/null 2>&1; then
                if [ "$COMPRESS" = true ]; then
                    docker run --rm \
                        -v "$volume_name:/data" \
                        -v "$BACKUP_DIR":/backup \
                        alpine tar czf "/backup/${volume_name}_${DATE}.tar.gz" -C /data .
                    encrypt_file "$BACKUP_DIR/${volume_name}_${DATE}.tar.gz"
                else
                    docker run --rm \
                        -v "$volume_name:/data" \
                        -v "$BACKUP_DIR":/backup \
                        alpine tar cf "/backup/${volume_name}_${DATE}.tar" -C /data .
                    encrypt_file "$BACKUP_DIR/${volume_name}_${DATE}.tar"
                fi
                echo -e "✅ $service backup completed"
            else
                echo -e "⚠️ Volume for $service not found"
            fi
            ;;
        picoclaw|picoclaw-gateway)
            if docker volume inspect picoclaw_data > /dev/null 2>&1; then
                if [ "$COMPRESS" = true ]; then
                    docker run --rm \
                        -v "picoclaw_data:/data" \
                        -v "$BACKUP_DIR":/backup \
                        alpine tar czf "/backup/picoclaw_data_${DATE}.tar.gz" -C /data .
                    encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar.gz"
                else
                    docker run --rm \
                        -v "picoclaw_data:/data" \
                        -v "$BACKUP_DIR":/backup \
                        alpine tar cf "/backup/picoclaw_data_${DATE}.tar" -C /data .
                    encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar"
                fi
                echo -e "✅ picoclaw backup completed"
            elif [ -d "data/picoclaw" ]; then
                if [ "$COMPRESS" = true ]; then
                    tar czf "$BACKUP_DIR/picoclaw_data_${DATE}.tar.gz" -C data picoclaw
                    encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar.gz"
                else
                    tar cf "$BACKUP_DIR/picoclaw_data_${DATE}.tar" -C data picoclaw
                    encrypt_file "$BACKUP_DIR/picoclaw_data_${DATE}.tar"
                fi
                echo -e "✅ picoclaw backup completed"
            else
                echo -e "⚠️ data/picoclaw not found"
            fi
            ;;
        *)
            echo -e "❌ Unknown service: $service"
            exit 1
            ;;
    esac
}

# Function to create backup manifest
create_manifest() {
    echo -e "📋 Creating backup manifest..."
    
    manifest_file="$BACKUP_DIR/backup_manifest_${DATE}.json"
    
    cat > "$manifest_file" << EOF
{
  "backup_date": "$DATE",
  "backup_type": "$BACKUP_TYPE",
  "services": "$SERVICES",
  "compressed": $COMPRESS,
  "encrypted": $ENCRYPT,
  "files": [$(find "$BACKUP_DIR" -name "*_${DATE}.*" -type f | sed 's/.*/"&"/' | paste -sd, -)],
  "ai_stack_version": "1.0",
  "created_by": "ai-stack-backup-script"
}
EOF
    
    echo -e "✅ Backup manifest created"
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo -e "🧹 Cleaning up old backups..."
    
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        echo "  🗑️ Removing backups older than $RETENTION_DAYS days..."
        find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "*.gz" -delete 2>/dev/null || true
        find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "*.tar" -delete 2>/dev/null || true
        find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "*.sql" -delete 2>/dev/null || true
        find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "*.enc" -delete 2>/dev/null || true
        find "$BACKUP_DIR" -type f -mtime +"$RETENTION_DAYS" -name "backup_manifest_*.json" -delete 2>/dev/null || true
        echo -e "✅ Cleanup completed"
    else
        echo "  ℹ️ Cleanup disabled (retention set to 0)"
    fi
}

# Function to show backup summary
show_summary() {
    echo ""
    echo -e "🎉 Backup Completed Successfully!"
    echo "=================================="
    echo "📅 Date: $DATE"
    echo "🗂️ Type: $BACKUP_TYPE"
    echo "📍 Location: $BACKUP_DIR"
    echo "🔒 Encrypted: $ENCRYPT"
    echo "📦 Compressed: $COMPRESS"
    
    if [ -n "$SERVICES" ]; then
        echo "🎯 Services: $SERVICES"
    fi
    
    echo ""
    echo "📊 Backup Files:"
    find "$BACKUP_DIR" -name "*_${DATE}.*" -type f | while read file; do
        size=$(du -h "$file" | cut -f1)
        echo "  📄 $(basename "$file") ($size)"
    done
    
    echo ""
    echo -e "💡 To restore this backup:"
    echo "  ./scripts/restore.sh --date $DATE"
    echo ""
}

# Main execution
main() {
    check_services
    setup_backup_dir
    
    echo -e "🔄 Starting $BACKUP_TYPE backup..."
    echo ""
    
    case "$BACKUP_TYPE" in
        full)
            if [ -n "$SERVICES" ]; then
                backup_service "$SERVICES"
            else
                backup_postgres
                backup_volumes
                backup_configs
            fi
            ;;
        data)
            if [ -n "$SERVICES" ]; then
                backup_service "$SERVICES"
            else
                backup_postgres
                backup_volumes
            fi
            ;;
        config)
            backup_configs
            ;;
        *)
            echo -e "❌ Unknown backup type: $BACKUP_TYPE"
            echo "Available types: full, data, config"
            exit 1
            ;;
    esac
    
    create_manifest
    cleanup_old_backups
    show_summary
}

# Check if backup is enabled
if [ "$BACKUP_ENABLED" != "true" ]; then
    echo -e "⚠️ Backup is disabled in configuration"
    echo "To enable: Set BACKUP_ENABLED=true in .env file"
    exit 1
fi

# Run main function
main "$@"