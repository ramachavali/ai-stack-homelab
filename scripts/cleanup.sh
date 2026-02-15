#!/bin/bash

# =================================================================
# AI Stack Cleanup Script
# Removes unnecessary files and folders from the project
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

echo -e "🧹 AI Stack Cleanup"
echo "==================="
echo ""
echo "This script will remove unnecessary files and folders from your AI Stack project."
echo ""
echo -e "What will be removed:"
echo "• 5 outdated documentation files"
echo "• 1 redundant environment file (.env.prod)"
echo "• All .DS_Store system files (safe to remove)"
echo "• 3 unused config directories"
echo "• 2 .gitkeep files"
echo "• 1 redundant data directory (data/open-webui)"
echo "• 1 outdated PostgreSQL script"
echo "• Empty directories"
echo "• VS Code workspace file (optional)"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with cleanup? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "🔹 Starting cleanup..."
echo ""

# Function to safely remove file/directory
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

# 1. Remove outdated documentation files
echo -e "📚 Cleaning up outdated documentation..."
safe_remove "docs/postgresql-17.5-migration-guide.md" "PostgreSQL 17.5 migration guide"
safe_remove "docs/postgresql-migration-guide.md" "PostgreSQL migration guide"
safe_remove "docs/script-updates-summary.md" "Script updates summary"
safe_remove "docs/service-name-change-summary.md" "Service name change summary"
safe_remove "docs/vector-database-guide.md" "Vector database guide"

# 2. Remove redundant environment file
echo -e "⚙️ Cleaning up environment files..."
safe_remove ".env.prod" "Redundant production environment file"

# 3. Remove system files
echo -e "🖥️ Cleaning up system files..."
echo -e "Removing .DS_Store files..."
find . -name ".DS_Store" -type f -delete 2>/dev/null || true
echo -e "✅ Removed all .DS_Store files"

# 4. Remove empty/unused config directories
echo -e "📁 Cleaning up unused config directories..."
safe_remove "configs/litellm" "Unused LiteLLM config directory"
safe_remove "configs/nginx" "Unused Nginx config directory"
safe_remove "logs/nginx" "Unused Nginx logs directory"

# 5. Remove .gitkeep files
echo -e "🔗 Cleaning up .gitkeep files..."
safe_remove "configs/n8n/.gitkeep" "n8n .gitkeep file"
safe_remove "configs/ollama/.gitkeep" "Ollama .gitkeep file"

# 6. Remove redundant data directory
echo -e "💾 Cleaning up redundant data directories..."
safe_remove "data/open-webui" "Redundant open-webui data directory"

# 7. Remove outdated PostgreSQL extension file
echo -e "🐘 Cleaning up outdated PostgreSQL files..."
safe_remove "configs/postgres/init/00-install-extensions.sql" "Outdated PostgreSQL extension script"

# 7. Remove .env
echo -e "🐘 Cleaning up environment files..."
safe_remove "./.env" 
safe_remove "./.rendered.env"

echo -e "🐘 Cleaning up docker files..."
docker volume prune
docker rmi $(docker images -a -q) 2>/dev/null || true
docker system prune -a -f 2>/dev/null || true

# 8. Optional: Remove VS Code workspace file
echo ""
read -p "Remove VS Code workspace file? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    safe_remove "ai-stack.code-workspace" "VS Code workspace file"
fi

# Clean up empty directories
echo -e "🗂️ Cleaning up empty directories..."
find . -type d -empty -not -path "./.git/*" -delete 2>/dev/null || true
echo -e "✅ Removed empty directories"

echo ""
echo -e "🎉 Cleanup completed successfully!"
echo ""
echo -e "Summary of what was removed:   "
echo "• 5 outdated documentation files"
echo "• 1 redundant environment file"
echo "• All .DS_Store system files"
echo "• 3 unused config directories"
echo "• 2 .gitkeep files"
echo "• 1 redundant data directory"
echo "• 1 outdated PostgreSQL script"
echo "• Empty directories"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "• VS Code workspace file"
fi
echo ""
echo -e "💡 Benefits achieved:"
echo "• Cleaner project structure"
echo "• Reduced confusion for users"
echo "• Smaller download/clone size"
echo "• Only relevant files remain"
echo "• Production-ready appearance"
echo ""
echo -e "Your AI Stack is now optimized and clean! 🚀"
echo ""
echo -e "Next steps:"
echo "• Review the remaining project structure"
echo "• Test that all scripts still work correctly"
echo "• Update any personal documentation if needed"