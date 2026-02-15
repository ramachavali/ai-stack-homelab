#!/bin/bash
# Ollama Model Initialization Script
# Auto-downloads required AI models on first startup

#!/usr/bin/env bash
set -o errexit
set -o nounset

set -x
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ollama-init-models.sh \
    [--llm <llm>] \
    [--llm <llm>]...

Examples:
  ./scripts/ollama-init-models.sh --llm llama3.2:3b --llm qwen2.5:7b-instruct

EOF
}
LLMS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --llm) LLMS+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ ${#LLMS[@]} -eq 0 ]] && { usage; exit 1; }


echo "🤖 Ollama Model Initialization"
echo "=============================="

# Wait for Ollama service to be ready
echo "⏳ Waiting for Ollama service to start..."
sleep 10

# Check if Ollama is responding
until ollama list > /dev/null 2>&1; do
    echo "⏳ Ollama not ready yet, waiting..."
    sleep 5
done

echo "✅ Ollama service is ready"
echo ""

# Function to check if model exists
model_exists() {
    ollama list | grep -Fxq -- "$1"
}

# Download llama3.2:3b
echo "📥 Checking if models exists..."
i=1
for model in "${LLMS[@]}"; do
    echo "Model ${i} = ${model}"
    if model_exists "$model"; then
    echo "✅ $model already downloaded"
else
    echo "⬇️  Downloading $model..."
    ollama pull "$model"
    echo "✅ $model downloaded successfully"
fi
echo ""
    i=$((i+1))
done

echo "🎉 All models ready!"
ollama list
