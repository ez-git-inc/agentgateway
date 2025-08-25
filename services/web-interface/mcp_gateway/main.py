#!/usr/bin/env python3
"""
AgentGateway Web Interface
Web server providing UI and API for AgentGateway library
"""

import os
import sys
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

try:
    from agentgateway.agent_gateway import AgentGateway, AgentType
    AGENTGATEWAY_AVAILABLE = True
except ImportError as e:
    AGENTGATEWAY_AVAILABLE = False
    AgentGateway = None
    AgentType = None
    print(f"AgentGateway import error: {e}")

app = FastAPI(
    title="AgentGateway Web Interface", 
    version="1.0.0",
    description="Web interface for AgentGateway library"
)

# HTML template for the UI
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AgentGateway - {title}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; 
            background: #f5f5f7; color: #1d1d1f; line-height: 1.6; 
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { 
            background: #fff; border-radius: 12px; padding: 24px; margin-bottom: 24px; 
            box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        }
        .header h1 { color: #007AFF; margin-bottom: 8px; }
        .nav { display: flex; gap: 12px; margin-bottom: 24px; }
        .nav a { 
            background: #007AFF; color: white; padding: 12px 20px; border-radius: 8px; 
            text-decoration: none; transition: all 0.2s; 
        }
        .nav a:hover { background: #0056b3; transform: translateY(-1px); }
        .nav a.active { background: #0056b3; }
        .card { 
            background: #fff; border-radius: 12px; padding: 24px; margin-bottom: 24px; 
            box-shadow: 0 2px 8px rgba(0,0,0,0.1); 
        }
        .status { 
            display: inline-block; padding: 4px 12px; border-radius: 20px; 
            font-size: 14px; font-weight: 500; 
        }
        .status.healthy { background: #d4edda; color: #155724; }
        .status.error { background: #f8d7da; color: #721c24; }
        .metrics-grid { 
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 16px; margin: 20px 0; 
        }
        .metric { background: #f8f9fa; padding: 16px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 24px; font-weight: bold; color: #007AFF; }
        .playground-form {
            display: flex; flex-direction: column; gap: 16px;
        }
        .playground-form input, .playground-form select, .playground-form textarea {
            padding: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 16px;
        }
        .playground-form button {
            background: #007AFF; color: white; padding: 12px 24px; border: none;
            border-radius: 8px; font-size: 16px; cursor: pointer;
        }
        .playground-form button:hover { background: #0056b3; }
        .response-box {
            background: #f8f9fa; border-radius: 8px; padding: 16px; margin-top: 16px;
            border-left: 4px solid #007AFF; white-space: pre-wrap; font-family: monospace;
        }
        .agent-list {
            display: grid; gap: 12px;
        }
        .agent-item {
            background: #f8f9fa; padding: 16px; border-radius: 8px;
            border-left: 4px solid #007AFF;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 AgentGateway Web Interface</h1>
            <p>Web interface for AgentGateway library - Version 1.0.0</p>
        </div>
        
        <nav class="nav">
            <a href="/" {home_active}>🏠 Dashboard</a>
            <a href="/playground" {playground_active}>🎮 Playground</a>
            <a href="/agents" {agents_active}>🤖 Agents</a>
            <a href="/tools" {tools_active}>🛠️ Tools</a>
        </nav>
        
        <div class="card">
            {content}
        </div>
    </div>
</body>
</html>
"""

class ChatRequest(BaseModel):
    message: str
    agent_type: str = "openai"
    model: str = "gpt-3.5-turbo"
    
@app.get("/", response_class=HTMLResponse)
async def dashboard():
    simple_html = """
    <!DOCTYPE html>
    <html>
    <head><title>AgentGateway</title></head>
    <body>
        <h1>🤖 AgentGateway Web Interface</h1>
        <p>Status: Available</p>
        <p><a href="/health">Health Check</a></p>
        <p><a href="/api/docs">API Documentation</a></p>
        <p><a href="/api/agents">List Agents</a></p>
    </body>
    </html>
    """
    return simple_html

@app.get("/playground", response_class=HTMLResponse)
async def playground():
    simple_playground = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>AgentGateway Playground</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            form { margin: 20px 0; }
            input, select, textarea, button { margin: 10px 0; padding: 10px; width: 300px; }
            button { width: 100px; background: #007AFF; color: white; border: none; border-radius: 5px; }
            #response { background: #f0f0f0; padding: 15px; margin: 20px 0; border-radius: 5px; white-space: pre-wrap; }
        </style>
    </head>
    <body>
        <h1>🎮 AgentGateway Playground</h1>
        <p>Interactive chat interface for testing AI agents</p>
        
        <form onsubmit="sendMessage(event)">
            <div>
                <label>Agent Type:</label><br>
                <select name="agent_type" id="agent_type">
                    <option value="openai">OpenAI GPT</option>
                    <option value="anthropic">Anthropic Claude</option>
                    <option value="groq">Groq</option>
                    <option value="bedrock">AWS Bedrock</option>
                </select>
            </div>
            
            <div>
                <label>Model:</label><br>
                <input type="text" name="model" id="model" placeholder="gpt-3.5-turbo" value="gpt-3.5-turbo">
            </div>
            
            <div>
                <label>Message:</label><br>
                <textarea name="message" id="message" placeholder="Enter your message..." rows="4"></textarea>
            </div>
            
            <button type="submit">Send</button>
        </form>
        
        <div id="response" style="display: none;"></div>
        
        <script>
        async function sendMessage(event) {
            event.preventDefault();
            const formData = new FormData(event.target);
            const data = {
                message: formData.get('message'),
                agent_type: formData.get('agent_type'),
                model: formData.get('model')
            };
            
            const responseDiv = document.getElementById('response');
            responseDiv.style.display = 'block';
            responseDiv.textContent = 'Sending message...';
            
            try {
                const response = await fetch('/api/chat', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify(data)
                });
                
                const result = await response.json();
                responseDiv.textContent = JSON.stringify(result, null, 2);
            } catch (error) {
                responseDiv.textContent = 'Error: ' + error.message;
            }
        }
        </script>
        
        <p><a href="/">← Back to Dashboard</a></p>
    </body>
    </html>
    """
    return simple_playground

@app.get("/agents", response_class=HTMLResponse)
async def agents():
    if not AGENTGATEWAY_AVAILABLE:
        agents_list = """
        <div style="background: #f8d7da; color: #721c24; padding: 16px; border-radius: 8px;">
            AgentGateway library not available.
        </div>
        """
    else:
        agents_list = """
        <div class="agent-list">
            <div class="agent-item">
                <h4>OpenAI GPT Agent</h4>
                <p>Supports GPT-3.5, GPT-4 and other OpenAI models</p>
            </div>
            <div class="agent-item">
                <h4>Anthropic Claude Agent</h4>
                <p>Claude 3 and other Anthropic models</p>
            </div>
            <div class="agent-item">
                <h4>Groq Agent</h4>
                <p>Fast inference with Groq's LPU technology</p>
            </div>
            <div class="agent-item">
                <h4>AWS Bedrock Agent</h4>
                <p>Access to AWS Bedrock foundation models</p>
            </div>
            <div class="agent-item">
                <h4>Fireworks AI Agent</h4>
                <p>Fireworks AI hosted models</p>
            </div>
            <div class="agent-item">
                <h4>Together AI Agent</h4>
                <p>Together AI platform models</p>
            </div>
        </div>
        """
    
    content = f"""
    <h2>🤖 Available Agents</h2>
    <p>AgentGateway supports multiple AI providers and models.</p>
    {agents_list}
    """
    
    return HTML_TEMPLATE.format(
        title="Agents",
        content=content,
        home_active='',
        playground_active='',
        agents_active='class="active"',
        tools_active=''
    )

@app.get("/tools", response_class=HTMLResponse) 
async def tools():
    content = """
    <h2>🛠️ Built-in Tools</h2>
    <p>AgentGateway includes various tools for enhanced agent capabilities.</p>
    
    <div class="agent-list">
        <div class="agent-item">
            <h4>Web Search Tool</h4>
            <p>Search the web for current information</p>
        </div>
        <div class="agent-item">
            <h4>Calculator Tool</h4>
            <p>Perform mathematical calculations</p>
        </div>
        <div class="agent-item">
            <h4>Weather Tool</h4>
            <p>Get weather information for any location</p>
        </div>
        <div class="agent-item">
            <h4>Translation Tool</h4>
            <p>Translate text between languages</p>
        </div>
        <div class="agent-item">
            <h4>Sentiment Analysis Tool</h4>
            <p>Analyze sentiment of text</p>
        </div>
        <div class="agent-item">
            <h4>Text Summarization Tool</h4>
            <p>Summarize long text content</p>
        </div>
        <div class="agent-item">
            <h4>Topic Detection Tool</h4>
            <p>Detect topics in text content</p>
        </div>
        <div class="agent-item">
            <h4>Ask User Tool</h4>
            <p>Interactive tool to ask user for input</p>
        </div>
    </div>
    """
    
    return HTML_TEMPLATE.format(
        title="Tools",
        content=content,
        home_active='',
        playground_active='',
        agents_active='',
        tools_active='class="active"'
    )

# API Endpoints
@app.get("/health")
async def health_check():
    return {
        "status": "healthy" if AGENTGATEWAY_AVAILABLE else "limited",
        "agentgateway_available": AGENTGATEWAY_AVAILABLE,
        "version": "1.0.0"
    }

@app.post("/api/chat")
async def chat(request: ChatRequest):
    if not AGENTGATEWAY_AVAILABLE:
        raise HTTPException(
            status_code=503, 
            detail="AgentGateway library not available"
        )
    
    try:
        # Initialize AgentGateway
        gateway = AgentGateway()
        
        # Map agent type string to enum
        agent_type_map = {
            "openai": AgentType.OPENAI_GPT,
            "anthropic": AgentType.ANTHROPIC_CLAUDE,
            "groq": AgentType.GROQ,
            "bedrock": AgentType.BEDROCK_CONVERSE
        }
        
        agent_type = agent_type_map.get(request.agent_type, AgentType.OPENAI_GPT)
        
        # This is a simplified version - actual implementation would need proper prompt handling
        # For now, return a mock response since we can't import the Prompt class easily
        response_text = f"Mock response for '{request.message}' using {request.agent_type} model {request.model}"
        
        return {
            "response": response_text,
            "agent_type": request.agent_type,
            "model": request.model,
            "status": "success"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

@app.get("/api/agents")
async def list_agents():
    if not AGENTGATEWAY_AVAILABLE:
        return {"agents": [], "available": False}
    
    return {
        "agents": [
            {"id": "openai", "name": "OpenAI GPT", "description": "OpenAI GPT models"},
            {"id": "anthropic", "name": "Anthropic Claude", "description": "Claude models"},
            {"id": "groq", "name": "Groq", "description": "Groq LPU models"},
            {"id": "bedrock", "name": "AWS Bedrock", "description": "Bedrock models"}
        ],
        "available": True
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
