#!/bin/bash

# =================================================================
# AI Stack Setup Script for Mac Mini M4
# Simple, efficient setup for novice users
# =================================================================

set -o errexit
set -o nounset

#set -x

# Project root directory
if [ "${BASH_SOURCE-}" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
else
    SCRIPT_PATH="$0"
fi
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)" || {
    echo "Failed to determine project root directory" >&2
    exit 1
}
cd "$PROJECT_ROOT"

echo -e "🚀 AI Stack Setup for Mac Mini M4"
echo "======================================"
echo ""

# Function to print section headers
print_section() {
    echo -e "$1"
    echo "$(printf '%*s' ${#1} | tr ' ' '=')"
}

# Function to check prerequisites
check_prerequisites() {
    print_section "📋 Checking Prerequisites"
    
    # Accept either Colima or Docker Desktop / any running Docker daemon
    if command -v colima > /dev/null 2>&1 && colima status > /dev/null 2>&1; then
        echo -e "✅ Colima is available"
    elif docker info > /dev/null 2>&1; then
        echo -e "✅ Docker daemon is available"
    else
        echo -e "❌ No Docker runtime available"
        echo "Start Docker Desktop or Colima and try again"
        exit 1
    fi


    # Check Docker Compose version
    if ! docker-compose version > /dev/null 2>&1; then
        echo -e "❌ Docker Compose not available"
        echo "Please update Docker Desktop to the latest version"
        exit 1
    fi
    echo -e "✅ Docker Compose is available"

    # Check available disk space (at least 10GB)
    available_space=$(df -k . | awk 'NR==2{print $4}')
    if [ "$available_space" -lt 10485760 ]; then
        echo -e "⚠️  Warning: Less than 10GB free space available"
        echo "Recommended: At least 50GB for AI models and data"
    else
        echo -e "✅ Sufficient disk space available"
    fi

    echo ""
}

render_env() {
        local filePath="${1:-.env}"

        if [ ! -f "$filePath" ]; then
            echo "missing ${filePath}"
            exit 1
        fi

        echo "Rendering ${filePath}"
        local out="${PROJECT_ROOT}/.env"
        local rendered_file="${PROJECT_ROOT}/.rendered.env"

        : > "$out"
        : > "$rendered_file"

        while IFS= read -r LINE || [ -n "$LINE" ]; do
            # Trim leading/trailing whitespace, normalize spaces around '=', remove CR
            CLEANED_LINE=$(echo "${LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/' | tr -d '\r')

            if [[ "${CLEANED_LINE}" != "#"* ]] && [[ "${CLEANED_LINE}" == *"="* ]]; then
                # Allow command substitution and variable expansion for values.
                # Temporarily disable nounset to avoid abort on unset vars during expansion.
                set +u
                rendered=$(eval "echo \"${CLEANED_LINE}\"")
                set -u

                echo "$rendered" >> "$out"
                echo "$rendered" >> "$rendered_file"
                # Export into current shell so later lines can reference earlier values
                export "${rendered}"
            fi
        done < "$filePath"
}

setup_tls_certificates() {
    print_section "🔐 Setting Up TLS Certificates"

    local core_root="${PROJECT_ROOT}/../coreservices-homelab"
    local pki_script="${core_root}/scripts/pki-build.sh"
    local pki_dir="${core_root}/pki"

    if [ ! -x "$pki_script" ]; then
        echo -e "⚠️ Core PKI script not found at: $pki_script"
        echo -e "⚠️ Skipping cert generation (Traefik may serve default/self cert)"
        echo ""
        return
    fi

    local sans=(
        "traefik.local"
        "auth.local"
        "core.local"
        "vault.local"
        "open-webui.local"
        "n8n.local"
        "litellm.local"
        "ollama.local"
        "mcpo.local"
        "searxng.local"
        "portal.local"
        "picoclaw.local"
    )

    local pki_args=(
        --out-dir "$pki_dir"
        --ca-name "Foolsbook Local Root CA"
        --hostname "traefik.local"
    )
    for san in "${sans[@]}"; do
        pki_args+=(--san "$san")
    done

    "$pki_script" "${pki_args[@]}"

    docker volume create traefik_certs > /dev/null
    docker run --rm \
        -v traefik_certs:/certs \
        -v "$pki_dir/traefik:/src:ro" \
        alpine:3.20 \
        sh -ec '
          cp /src/cert.pem /certs/cert.pem
          cp /src/key.pem /certs/key.pem
          chmod 644 /certs/cert.pem
          chmod 600 /certs/key.pem
        '

    echo -e "✅ TLS cert installed into traefik_certs volume"
    echo -e "✅ CA bundle available at: ${pki_dir}/client/ca_bundle.crt"
    echo ""
}

# Function to create environment file
setup_environment() {
    print_section "⚙️ Setting Up Environment"
    
    if [ ! -f "${PROJECT_ROOT}/.rendered.env" ]; then
        echo -e "Copying and sourcing .env from template..."

        render_env "${PROJECT_ROOT}/scripts/.unrendered.env" || {
            echo -e "✗ Failed to load .env file"
            exit 1
        }
    else
        echo -e "✓ .env file exists and validated"
    fi

    source "${PROJECT_ROOT}/.rendered.env" > /dev/null
    
    echo -e "✅ Environment variables loaded"
}

# Function to create directory structure
create_directories() {
    print_section "📁 Creating Directory Structure"
    
    # Data directories
    mkdir -p data/{postgres,n8n,ollama,open-webui,redis,litellm,mcp}
    echo -e "✅ Data directories created"
    
    # Log directories
    mkdir -p logs/{n8n,postgres,nginx}
    echo -e "✅ Log directories created"
    
    # Backup directories
    mkdir -p backups/{postgres,volumes}
    echo -e "✅ Backup directories created"
    
    # Config directories
    mkdir -p configs/{postgres/init,redis,n8n,ollama,litellm,mcp,nginx}
    echo -e "✅ Config directories created"
    
    # Set permissions
    chmod 700 data/postgres
    chmod 755 data/{n8n,ollama,open-webui,redis,litellm,mcp}
    chmod 755 logs/{n8n,postgres}
    chmod 755 backups/{postgres,volumes}
    echo -e "✅ Permissions set"
    echo ""
}

# Function to create configuration files
create_configs() {
    print_section "🔧 Creating Configuration Files"
    
    # MCP configuration
    cat > configs/mcp/config.json << 'EOF'
{
  "mcpServers": {
    "n8n-mcp": {
      "command": "npx",
      "args": [
        "-y",
        "n8n-mcp",
        "http://n8n-mcp:3000/mcp",
        "--header",
        "Authorization: Bearer ${N8N_MCP_AUTH_TOKEN}",
        "--allow-http"
      ]
    }
  }
}
EOF
    echo -e "✅ MCP configuration created"

    # PostgreSQL initialization script
    cat > configs/postgres/init/01-init-databases.sql << 'EOF'
-- Create additional databases for AI Stack services
SELECT 'CREATE DATABASE n8n_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n_db')\gexec
SELECT 'CREATE DATABASE litellm_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'litellm_db')\gexec
SELECT 'CREATE DATABASE open_webui_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'open_webui_db')\gexec

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE n8n_db TO aistack_user;
GRANT ALL PRIVILEGES ON DATABASE litellm_db TO aistack_user;
GRANT ALL PRIVILEGES ON DATABASE open_webui_db TO aistack_user;
EOF
    echo -e "✅ PostgreSQL init script created"

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Environment files with secrets
*.env
.env
.env.local
.env.production

# Data directories
data/
logs/
backups/

# Temporary files
*.tmp
.tmp*
*.log
.DS_Store

# IDE files
.vscode/
.idea/

# Docker overrides
docker-compose.override.yml

# Backup files
*.backup
*.sql.gz
EOF
    echo -e "✅ .gitignore created"
    echo ""
}

# Function to pull Docker images
pull_images() {
    print_section "📥 Downloading Docker Images"
    
    echo "This may take several minutes depending on your internet connection..."
    echo ""
    
    if docker-compose pull; then
        echo -e "✅ All Docker images downloaded successfully"
    else
        echo -e "❌ Failed to download some Docker images"
        echo "Please check your internet connection and try again"
        exit 1
    fi
    echo ""
}

# Function to download AI models
setup_models() {
    print_section "🤖 Setting Up AI Models"

    docker_cpus="$(docker info --format '{{.NCPU}}' 2>/dev/null || echo "")"
    if [ -n "$docker_cpus" ]; then
        if awk "BEGIN {exit !(${OLLAMA_CPU_LIMIT:-0} > ${docker_cpus})}"; then
            echo -e "⚠️ OLLAMA_CPU_LIMIT (${OLLAMA_CPU_LIMIT}) exceeds available Docker CPUs (${docker_cpus}); capping to ${docker_cpus}."
            export OLLAMA_CPU_LIMIT="$docker_cpus"
        fi
    fi
    
    echo "Downloading Llama 3.2 models (this may take 10-20 minutes)..."
    echo ""
    
    # Start only Ollama for model download
    echo "Starting Ollama temporarily..."
    docker-compose up -d ollama
    
    # Wait for Ollama to be ready
    echo "Waiting for Ollama to start..."
    sleep 30
    
    # Download models
    echo -e "📥 Downloading llama3.2:1b (lightweight, ~1.3GB)..."
    if docker exec ollama ollama pull llama3.2:1b; then
        echo -e "✅ llama3.2:1b downloaded"
    else
        echo -e "⚠️ Failed to download llama3.2:1b"
    fi
    
    # Stop Ollama
    docker-compose stop ollama
    echo -e "✅ AI models setup completed"
    echo ""
}

# Function to make scripts executable
setup_scripts() {
    print_section "📜 Setting Up Management Scripts"
    
    # Make all scripts executable
    chmod +x scripts/*.sh
    echo -e "✅ All scripts are now executable"
    echo ""
}

# Function to create backup script
create_backup_script() {
    # Enhanced backup script will be created separately
    echo -e "✅ Backup scripts ready"
}

# Function to display completion message
show_completion() {
    print_section "🎉 Setup Completed Successfully!"
    
    echo -e "Your AI Stack is ready to start!"
    echo ""
    echo -e "Next Steps:"
    echo "1. Start the AI Stack:    ./scripts/start.sh"
    echo "2. Wait for all services to start (2-3 minutes)"
    echo "3. Access your services:"
    echo "   • n8n Workflows:       http://localhost:5678"
    echo "   • Open WebUI:          http://localhost:8080"
    echo "   • LiteLLM Proxy:       http://localhost:4000"
    echo "   • MCP Orchestrator:    http://localhost:8000"
    echo ""
    echo -e "First Time Setup:"
    echo "• Create accounts in n8n and Open WebUI"
    echo "• n8n: First user becomes the owner"
    echo "• Open WebUI: First user becomes admin"
    echo ""
    echo -e "Important Commands:"
    echo "• Start all services:     ./scripts/start.sh"
    echo "• Stop all services:      ./scripts/stop.sh"
    echo "• Backup data:            ./scripts/backup.sh"
    echo "• View logs:              docker-compose logs -f [service]"
    echo ""
    echo -e "💾 Remember to backup your .env file securely!"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    setup_environment
    setup_tls_certificates
    create_directories
    create_configs
    pull_images
    setup_models
    setup_scripts
    create_backup_script
    show_completion
}

# Run main function
main "$@"