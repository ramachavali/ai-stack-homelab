#!/bin/bash
# =================================================================
# AI Stack Setup Script
# Streamlined initialization for home lab deployment
# =================================================================

set -e

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"
NC="\033[0m"

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}${BOLD}🚀 AI Stack Setup${NC}"
echo "=================================="
echo ""

# Step 1: Check Docker
echo -e "${BLUE}[1/4]${NC} Checking Docker..."
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo ""
    echo "Please start Docker Desktop and run this script again"
    exit 1
fi
echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Step 2: Create .env file
echo -e "${BLUE}[2/4]${NC} Configuring environment..."
if [ ! -f .env ]; then
    echo -e "${YELLOW}Copying and sourcing .env from template...${NC}"
    cp scripts/.env.example .env
    source .env > /dev/null 2>&1 || {
        echo -e "${RED}✗ Failed to load .env${NC}"
        exit 1
    }

else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi
echo ""

# Step 3: Pull Docker images
echo -e "${BLUE}[3/4]${NC} Downloading Docker images..."
echo "This may take several minutes..."
if docker-compose pull; then
    echo -e "${GREEN}✓ All images downloaded${NC}"
else
    echo -e "${RED}✗ Failed to download images${NC}"
    exit 1
fi
echo ""

# Step 4: Generate self-signed SSL certificate for Traefik
echo -e "${BLUE}[4/4]${NC} Generating SSL certificates..."
mkdir -p certs
if [ ! -f certs/cert.pem ] || [ ! -f certs/key.pem ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout certs/key.pem \
        -out certs/cert.pem \
        -subj "/C=US/ST=State/L=City/O=AI-Stack/CN=*.local" \
        -addext "subjectAltName=DNS:*.local,DNS:localhost" \
        > /dev/null 2>&1
    echo -e "${GREEN}✓ SSL certificates generated${NC}"
else
    echo -e "${GREEN}✓ SSL certificates already exist${NC}"
fi
echo ""

# Completion message
echo -e "${GREEN}${BOLD}✓ Setup Complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Start the stack:  ${BLUE}docker-compose up -d${NC}"
echo "  2. Download models:  ${BLUE}docker exec ollama sh -c '/bin/bash /root/.ollama/init-models.sh' &${NC}"
echo "     (This runs in background and takes 10-20 minutes)"
echo ""
echo "  3. Access services at:"
echo "     • Open WebUI:    ${BLUE}https://open-webui.local${NC}"
echo "     • n8n:           ${BLUE}https://n8n.local${NC}"
echo "     • LiteLLM:       ${BLUE}https://litellm.local${NC}"
echo "     • SearXNG:       ${BLUE}https://searxng.local${NC}"
echo "     • Traefik:       ${BLUE}https://traefik.local${NC}"
echo ""
echo "Note: Add these entries to /etc/hosts:"
echo "  ${YELLOW}127.0.0.1 open-webui.local n8n.local litellm.local traefik.local ollama.local mcpo.local searxng.local${NC}"
echo ""
echo "Monitor with: ${BLUE}docker-compose logs -f${NC}"
echo ""
