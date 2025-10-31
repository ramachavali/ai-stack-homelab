#!/bin/bash
# Ollama Model Initialization Script
# Auto-downloads required AI models on first startup

set -e

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
    ollama list | grep -q "^$1"
}

# Download llama3.2:3b
echo "📥 Checking llama3.2:3b..."
if model_exists "llama3.2:3b"; then
    echo "✅ llama3.2:3b already downloaded"
else
    echo "⬇️  Downloading llama3.2:3b (~2GB)..."
    ollama pull llama3.2:3b
    echo "✅ llama3.2:3b downloaded successfully"
fi
echo ""

# Download qwen2.5:7b-instruct
echo "📥 Checking qwen2.5:7b-instruct..."
if model_exists "qwen2.5:7b-instruct"; then
    echo "✅ qwen2.5:7b-instruct already downloaded"
else
    echo "⬇️  Downloading qwen2.5:7b-instruct (~4.7GB)..."
    ollama pull qwen2.5:7b-instruct
    echo "✅ qwen2.5:7b-instruct downloaded successfully"
fi
echo ""

# Download nomic-embed-text (for embeddings)
echo "📥 Checking nomic-embed-text..."
if model_exists "nomic-embed-text"; then
    echo "✅ nomic-embed-text already downloaded"
else
    echo "⬇️  Downloading nomic-embed-text (~274MB)..."
    ollama pull nomic-embed-text
    echo "✅ nomic-embed-text downloaded successfully"
fi
echo ""

echo "🎉 All models ready!"
ollama list
