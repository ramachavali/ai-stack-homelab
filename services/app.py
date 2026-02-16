from flask import Flask, render_template
import os


app = Flask(__name__)


@app.get("/")
def home():
    ai_links = [
        {
            "name": "Open WebUI",
            "url": os.getenv("OPEN_WEBUI_URL", "https://open-webui.local"),
            "description": "Primary AI chat interface",
        },
        {
            "name": "n8n",
            "url": os.getenv("N8N_URL", "https://n8n.local"),
            "description": "Workflow automation",
        },
        {
            "name": "LiteLLM",
            "url": os.getenv("LITELLM_URL", "https://litellm.local"),
            "description": "LLM proxy and routing",
        },
        {
            "name": "SearXNG",
            "url": os.getenv("SEARXNG_URL", "https://searxng.local"),
            "description": "Meta web search",
        },
        {
            "name": "Ollama",
            "url": os.getenv("OLLAMA_URL", "https://ollama.local"),
            "description": "Model runtime API",
        },
        {
            "name": "MCPO",
            "url": os.getenv("MCPO_URL", "https://mcpo.local"),
            "description": "MCP orchestrator",
        },
    ]

    core_links = [
        {
            "name": "Core Frontend",
            "url": os.getenv("CORE_FRONTEND_URL", "https://core.local"),
            "description": "Core services landing page",
        },
        {
            "name": "Traefik Dashboard",
            "url": os.getenv("TRAEFIK_UI_URL", "https://traefik.local"),
            "description": "Routing and reverse-proxy status",
        },
        {
            "name": "Logto UI",
            "url": os.getenv("LOGTO_UI_URL", "https://auth.local"),
            "description": "Authentication and identity",
        },
        {
            "name": "Vault UI",
            "url": os.getenv("VAULT_UI_URL", "http://localhost:8200/ui"),
            "description": "Secrets and policies",
        },
    ]

    return render_template(
        "index.html",
        title=os.getenv("PORTAL_TITLE", "AI + Core Services Portal"),
        ai_links=ai_links,
        core_links=core_links,
    )


@app.get("/health")
def health():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
