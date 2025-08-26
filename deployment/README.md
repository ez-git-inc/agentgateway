# Official AgentGateway Deployment Guide

This directory contains deployment scripts for the **official Rust AgentGateway** implementation.

## 🚀 What This Deploys

**Official Rust AgentGateway** - The complete, production-ready AgentGateway with:

- ✅ **Multi-protocol support** (MCP, A2A, HTTP, WebSocket, gRPC)
- ✅ **Built-in Next.js web UI** (served at `/ui`)
- ✅ **Admin endpoints** (port 15000)
- ✅ **Metrics & health checks** (ports 15001, 15002)
- ✅ **High performance** (Rust implementation)
- ✅ **Auto-scaling** (Cloud Run)
- ✅ **Service integration** (orionOrchestrator, orionCreate)

## 🏗️ Structure

```
deployment/
├── scripts/
│   └── deploy-agentgateway.sh    # Official AgentGateway deployment
└── README.md                     # This documentation
```

## 🛠️ Quick Start

### Deploy Official AgentGateway

```bash
# From AgentGateway repository root
./deployment/scripts/deploy-agentgateway.sh

# With custom project
./deployment/scripts/deploy-agentgateway.sh --project-id your-project-id

# Staging environment
./deployment/scripts/deploy-agentgateway.sh --environment staging
```

### Environment Variables

```bash
export GCP_PROJECT_ID="your-project-id"
export DEPLOY_ENV="production"  # or "staging"
```

## 📋 What Gets Deployed

- **Service Name**: `agentgateway`
- **Region**: `us-east1` 
- **Container Registry**: `us-east1-docker.pkg.dev/{project}/agentgateway/agentgateway`
- **Admin Port**: 15000 (UI & admin endpoints)
- **Traffic Port**: 8080 (HTTP traffic)
- **Stats Port**: 15001 (metrics)
- **Readiness Port**: 15002 (health checks)

### Resource Allocation

**Production:**
- Memory: 4Gi
- CPU: 4 vCPU
- Instances: 1-20 (auto-scaling)
- Min instances: 1 (always ready)

**Staging:**
- Memory: 2Gi
- CPU: 2 vCPU
- Instances: 0-10 (scale-to-zero)
- Min instances: 0 (cost-effective)

## 🔗 Service Integration

AgentGateway automatically detects and integrates with orion services:
- **orionOrchestrator** - Workflow orchestration integration
- **orionCreate** - Content creation service integration

Integration is automatic via service discovery in the same GCP region.

## 📊 Endpoints

Once deployed, AgentGateway provides:

- **Web UI**: `https://agentgateway-xxx.run.app/ui` 🎮
- **Health Check**: `https://agentgateway-xxx.run.app/health` ❤️
- **Admin Interface**: `https://agentgateway-xxx.run.app/admin` ⚙️
- **MCP Endpoints**: `https://agentgateway-xxx.run.app/mcp/` 🤖
- **API Documentation**: Auto-generated OpenAPI docs

## 🎯 Prerequisites

- **Google Cloud SDK** (gcloud)
- **Docker** (for building images)
- **GCP Project** with appropriate permissions
- **Enabled APIs**: Cloud Run, Artifact Registry, Cloud Build

## ⚙️ Deployment Options

```bash
./deployment/scripts/deploy-agentgateway.sh [OPTIONS]

Options:
  --project-id PROJECT_ID    GCP Project ID (default: from env)
  --environment ENV          Environment: production|staging (default: production)
  --skip-build              Skip Docker image building (use existing)
  --skip-tests              Skip health check validation
  --help                    Show help message
```

### Example Commands

```bash
# Production deployment
./deployment/scripts/deploy-agentgateway.sh --project-id myproject

# Staging with existing image
./deployment/scripts/deploy-agentgateway.sh --environment staging --skip-build

# Quick deploy without validation
./deployment/scripts/deploy-agentgateway.sh --skip-tests
```

## 🧪 Testing Deployment

After deployment, test your AgentGateway:

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe agentgateway \
  --region=us-east1 --format="value(status.url)")

# Test endpoints
curl ${SERVICE_URL}/health
curl ${SERVICE_URL}/ui
curl ${SERVICE_URL}/admin

# Open web interface
open ${SERVICE_URL}/ui
```

## 🔧 Configuration

AgentGateway uses YAML configuration. The deployment script creates a production-ready config automatically, but you can customize:

```yaml
# Example config.yaml
config:
  adminAddr: "0.0.0.0:15000"
  statsAddr: "0.0.0.0:15001" 
  readinessAddr: "0.0.0.0:15002"

binds:
- port: 8080
  listeners:
  - protocol: HTTP
    routes:
    - name: mcp-route
      matches:
      - path:
          pathPrefix: /mcp
      backends:
      - mcp:
          targets:
          - stdio:
              cmd: "your-mcp-server"
```

## 🚀 Integration Examples

### With orionOrchestrator
AgentGateway will automatically integrate if orionOrchestrator is deployed:

```bash
# AgentGateway detects: https://orion-orchestrator-xxx.run.app
# Environment variables set automatically:
# ORCHESTRATOR_URL=https://orion-orchestrator-xxx.run.app
# ORCHESTRATOR_ENABLED=true
```

### With orionCreate
Similarly for orionCreate:

```bash
# AgentGateway detects: https://orion-create-xxx.run.app  
# Environment variables set automatically:
# CREATE_URL=https://orion-create-xxx.run.app
# CREATE_ENABLED=true
```

---

**Repository**: Official AgentGateway  
**Type**: Rust Implementation  
**Updated**: August 2025
