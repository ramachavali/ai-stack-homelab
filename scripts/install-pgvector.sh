#!/bin/bash

# =================================================================
# AI Stack pgvector Installation Script
# Simple, comprehensive installation for pgvector extension
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
    echo -e "❌ .rendered.env file not found"
    exit 1
fi


echo -e "🔧 pgvector Installation Script"
echo "=================================="

# Check if PostgreSQL is running
if ! docker-compose ps postgresql | grep -q "Up"; then
    echo -e "❌ PostgreSQL is not running. Please start it first with: ./scripts/start.sh"
    exit 1
fi

# Check if pgvector is already installed
echo -e "🔍 Checking if pgvector is already installed..."
if docker exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1 FROM pg_extension WHERE extname = 'vector';" 2>/dev/null | grep -q "1"; then
    echo -e "✅ pgvector extension is already installed and enabled"
    exit 0
fi

echo -e "⚠️  pgvector extension not found. Installing..."

# Method 1: Try to install from PostgreSQL repositories
echo -e "📦 Attempting to install pgvector from PostgreSQL repositories..."
if docker exec postgresql bash -c "apt-get update && apt-get install -y postgresql-17-pgvector" 2>/dev/null; then
    echo -e "✅ pgvector installed successfully from repositories"
else
    echo -e "⚠️  Could not install from repositories. Trying alternative method..."
    
    # Method 2: Install build dependencies and compile from source
    echo -e "🔨 Installing build dependencies and compiling pgvector from source... "
    docker exec postgresql bash -c "
        apt-get update &&
        apt-get install -y build-essential git postgresql-server-dev-17 &&
        cd /tmp &&
        git clone --branch v0.7.0 https://github.com/pgvector/pgvector.git &&
        cd pgvector &&
        make &&
        make install &&
        rm -rf /tmp/pgvector
    "
    echo -e "✅ pgvector compiled and installed from source"
fi

# Restart PostgreSQL to load the new extension
echo -e "🔄 Restarting PostgreSQL to load pgvector..."
docker-compose restart postgresql

# Wait for PostgreSQL to be ready
echo -e "⏳ Waiting for PostgreSQL to be ready..."
until docker exec postgresql pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo -e "\n✅ PostgreSQL is ready"

# Create the extension
echo -e "🔧 Creating pgvector extension..."
docker exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Verify installation
echo -e "🔍 Verifying installation..."
if docker exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1 FROM pg_extension WHERE extname = 'vector';" | grep -q "1"; then
    echo -e "✅ pgvector extension installed and enabled successfully!"
    
    # Test vector operations
    echo -e "🧪 Testing vector operations..."
    if docker exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT '[1,2,3]'::vector;" 2>/dev/null | grep -q "vector"; then
        echo -e "✅ Vector operations working correctly!"
    else
        echo -e "⚠️  Vector operations test failed"
    fi
else
    echo -e "❌ Failed to install pgvector extension"
    exit 1
fi

echo -e "🎉 pgvector installation completed successfully!" 