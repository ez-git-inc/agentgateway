# AgentGateway Deployment Guide

This directory contains deployment scripts and services for the AgentGateway MCP ecosystem.

## 🚀 Structure

```
deployment/
├── scripts/
│   └── deploy-agentgateway.sh    # Standalone deployment script
└── README.md                     # This documentation

services/
├── web-interface/                # FastAPI web interface for AgentGateway
│   ├── main.py                   # Web application
│   ├── Dockerfile               # Container configuration
│   ├── requirements.txt          # Python dependencies
│   ├── tests/                    # Unit tests
│   ├── deployment/               # Integration scripts
│   └── services/                 # Nested services (Context7 MCP)
```

## 🛠️ Quick Start

### Deploy AgentGateway Web Interface

```bash
# From AgentGateway repository root
./deployment/scripts/deploy-agentgateway.sh

# With options
./deployment/scripts/deploy-agentgateway.sh --environment staging --project-id your-project
```

### Environment Variables

Set these before deployment:
```bash
export GCP_PROJECT_ID="your-project-id"
export DEPLOY_ENV="production"  # or "staging"
```

## 📋 What Gets Deployed

- **Service Name**: `agentgateway-mcp`
- **Region**: `us-east1`
- **Container Registry**: `us-east1-docker.pkg.dev/{project}/orion-mcp/agentgateway-mcp`
- **Port**: 8080

### Resource Allocation

**Production:**
- Memory: 4Gi
- CPU: 4 vCPU
- Instances: 1-20 (auto-scaling)

**Staging:**
- Memory: 2Gi
- CPU: 2 vCPU
- Instances: 0-10 (scale-to-zero)

## 🔗 Service Integration

The AgentGateway automatically detects and integrates with:
- **Context7 MCP** (if deployed in same region)
- **Other MCP services** via service discovery

## 📊 Endpoints

Once deployed, AgentGateway provides:
- **Dashboard**: `https://agentgateway-mcp-xxx.run.app/`
- **Health Check**: `https://agentgateway-mcp-xxx.run.app/health`
- **MCP Discovery**: `https://agentgateway-mcp-xxx.run.app/mcp/`
- **API Docs**: `https://agentgateway-mcp-xxx.run.app/docs`
- **Admin Stats**: `https://agentgateway-mcp-xxx.run.app/admin/stats`

## 🎯 Prerequisites

- Google Cloud SDK (gcloud)
- Docker
- Appropriate GCP project permissions
- Enabled APIs: Cloud Run, Artifact Registry

## ⚙️ Options

```bash
./deployment/scripts/deploy-agentgateway.sh [OPTIONS]

Options:
  --project-id PROJECT_ID    GCP Project ID
  --environment ENV          Deployment environment (production/staging)
  --skip-build              Skip Docker image building
  --skip-tests              Skip integration tests
  --help                    Show help message
```

## 🔧 Development

The web interface is a FastAPI application that provides:
- Modern web UI for AgentGateway interaction
- REST API endpoints for programmatic access
- Integration with multiple AI providers
- MCP protocol support

## 🚀 Integration with Other Systems

This AgentGateway can be integrated with other systems (like orionConnect) by:
1. Deploying AgentGateway first
2. Other systems will auto-detect the service via Cloud Run service discovery
3. Environment variables will be set automatically for integration

---

**Repository**: AgentGateway Standalone  
**Updated**: August 2024
