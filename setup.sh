#!/bin/bash
# =================================================================
# AI Stack Setup Script
# Streamlined initialization for home lab deployment
# =================================================================

set -o errexit
set -o nounset

set -x


# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo -e "🚀 AI Stack Setup"
echo "=================================="
echo ""

# Step 1: Check Docker
echo -e "[1/4] Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "✗ Docker is not running"
    echo ""
    echo "Please start Docker Desktop and run this script again"
    exit 1
fi
echo -e "✓ Docker is running"
echo ""

# Step 2: Create .env file
echo -e "[2/4] Configuring environment..."
if [ ! -f .env ]; then
    echo -e "Copying and sourcing .env from template..."
    cp scripts/.env.example .env
    source ./.env > /dev/null 2>&1 || {
        echo -e "✗ Failed to load .env file"
        exit 1
    }

else
    env
    env >> .tmp.env
    echo -e "✓ .env file exists and loaded"
fi
echo ""

# Step 3: Pull Docker images
echo -e "[3/4] Downloading Docker images..."
echo "This may take several minutes..."
if docker-compose pull; then
    echo -e "✓ All images downloaded successfully"
else
    echo -e "✗ Failed to download images"
    exit 1
fi
echo ""

# Step 4: Generate self-signed SSL certificate for Traefik
echo -e "[4/4] Generating SSL certificates..."
mkdir -p certs
if [ ! -f certs/cert.pem ] || [ ! -f certs/key.pem ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout certs/key.pem \
        -out certs/cert.pem \
        -subj "/C=US/ST=State/L=City/O=AI-Stack/CN=*.local" \
        -addext "subjectAltName=DNS:*.local,DNS:localhost" \
        > /dev/null 2>&1
    echo -e "✓ SSL certificates generated"
else
    echo -e "✓ SSL certificates already exist"
fi
echo ""

# Completion message
echo -e "✓ Setup Complete!"
echo ""
echo "Next steps:"
echo "  1. Start the ollama:  docker-compose up -d ollama"
echo "  2. copy init file: docker cp configs/ollama/init-models.sh ollama:/root/.ollama/init-models.sh"
echo "  3. Download models:  docker exec ollama sh -c '/bin/bash /root/.ollama/init-models.sh --llm llama3.2:3b --llm granite4:latest --llm gemma3:latest ' &"
echo "     (This runs in background and takes 10-20 minutes)"
echo "  4. Start the stack:  docker-compose up -d"
echo ""
echo "  5. Access services at:"
echo "     • Open WebUI:    https://open-webui.local"
echo "     • n8n:           https://n8n.local"
echo "     • LiteLLM:       https://litellm.local"
echo "     • SearXNG:       https://searxng.local"
echo "     • Traefik:       https://traefik.local"
echo ""
echo "Note: Add these entries to /etc/hosts:"
echo "  127.0.0.1 open-webui.local n8n.local litellm.local traefik.local ollama.local mcpo.local searxng.local"
echo ""
echo "Monitor with: docker-compose logs -f"
echo ""
