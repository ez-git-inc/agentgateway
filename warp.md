# AgentGateway

## Overview

**AgentGateway** is an open-source data plane optimized for agentic AI connectivity within or across any agent framework or environment. It provides drop-in security, observability, and governance for agent-to-agent and agent-to-tool communication, supporting leading interoperable protocols including Agent2Agent (A2A) and Model Context Protocol (MCP).

Built with Rust for high performance and designed to handle any scale, agentgateway serves as the first complete connectivity solution for Agentic AI.

## 🚀 Key Features

- **🔒 Security First**: Robust MCP/A2A focused RBAC system with JWT authentication
- **🏢 Multi-Tenant**: Support for multiple tenants with isolated resources and users
- **⚡ High Performance**: Written in Rust from the ground up for maximum performance
- **🔄 Dynamic Configuration**: xDS-based configuration updates without downtime
- **🌍 Run Anywhere**: Compatible with any agent framework, from single machines to large-scale deployments
- **🔧 Legacy API Support**: Transform legacy APIs (OpenAPI) into MCP resources
- **🤖 AI Integration**: Native support for multiple AI providers (OpenAI, Gemini, Anthropic, etc.)
- **📊 Observability**: Built-in metrics, tracing, and telemetry

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Agents    │◄──►│AgentGateway │◄──►│   Tools/    │
│             │    │             │    │  Services   │
│  • MCP      │    │  • Routing  │    │  • MCP      │
│  • A2A      │    │  • Security │    │  • OpenAPI  │
│  • HTTP     │    │  • Policies │    │  • HTTP     │
└─────────────┘    └─────────────┘    └─────────────┘
```

## 📁 Repository Structure

```
agentgateway/
├── crates/                     # Rust workspace crates
│   ├── a2a-sdk/               # Agent2Agent SDK
│   ├── agentgateway/          # Core gateway implementation
│   ├── agentgateway-app/      # Application entry point
│   ├── core/                  # Shared core functionality
│   ├── hbone/                 # HBONE protocol support
│   ├── xds/                   # xDS configuration management
│   └── mock-server/           # Testing utilities
├── ui/                        # Next.js web interface
├── examples/                  # Configuration examples
├── schema/                    # JSON schemas for configuration
├── architecture/              # Architecture documentation
├── manifests/                 # Deployment manifests
└── img/                       # Images and assets
```

### Core Components

1. **AgentGateway Core** (`crates/agentgateway/`): Main gateway logic, routing, and policies
2. **A2A SDK** (`crates/a2a-sdk/`): Agent-to-Agent protocol implementation
3. **XDS** (`crates/xds/`): Dynamic configuration management
4. **HBONE** (`crates/hbone/`): HTTP-based overlay network
5. **UI** (`ui/`): Web-based management interface
6. **Core** (`crates/core/`): Shared utilities and telemetry

## 🛠️ Development Setup

### Prerequisites

- **Rust**: 1.89+ (see `rust-toolchain.toml`)
- **Node.js**: 10+ (for UI development)
- **Make**: For build automation

### Building from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/agentgateway/agentgateway.git
   cd agentgateway
   ```

2. **Build the UI**:
   ```bash
   cd ui
   npm install
   npm run build
   cd ..
   ```

3. **Build the gateway**:
   ```bash
   CARGO_NET_GIT_FETCH_WITH_CLI=true
   make build
   ```

4. **Run the gateway**:
   ```bash
   ./target/release/agentgateway
   ```

### Development Commands

- `make build` - Build release binary
- `make test` - Run all tests
- `make lint` - Check code formatting and linting
- `make fix-lint` - Fix linting issues automatically
- `make gen` - Generate APIs and schemas
- `make docker` - Build Docker image

## 🚀 Quick Start

### 1. Basic Configuration

Create a minimal configuration file:

```yaml
# minimal-config.yaml
config:
  adminAddr: "127.0.0.1:15000"
  statsAddr: "127.0.0.1:15001"
  readinessAddr: "127.0.0.1:15002"

binds:
- port: 3000
  listeners:
  - protocol: HTTP
    routes:
    - name: health
      matches:
      - path:
          pathPrefix: /health
      policies:
        directResponse:
          body: "AgentGateway is running!"
          status: 200
```

### 2. Run the Gateway

```bash
./target/release/agentgateway -f minimal-config.yaml
```

### 3. Access the UI

Open your browser to `http://localhost:15000/ui` to access the management interface.

### 4. Test the Gateway

```bash
curl http://localhost:3000/health
# Response: AgentGateway is running!
```

## 📋 Configuration Examples

### MCP Server Integration

```yaml
binds:
- port: 3000
  listeners:
  - protocol: HTTP
    routes:
    - name: mcp-server
      matches:
      - path:
          pathPrefix: /mcp
      backends:
      - mcp:
          targets:
          - stdio:
              cmd: "python"
              args: ["mcp_server.py"]
```

### Authentication & Authorization

```yaml
routes:
- name: protected-resource
  matches:
  - path:
      pathPrefix: /api
  policies:
    jwtAuth:
      issuer: "https://your-auth-provider.com"
      audiences: ["your-audience"]
      jwks:
        url: "https://your-auth-provider.com/.well-known/jwks.json"
    authorization:
      rules:
      - allow: 'jwt.sub == "authorized-user"'
```

### AI Provider Integration

```yaml
backends:
- ai:
    provider:
      openAI:
        model: "gpt-4"
    policies:
      ai:
        promptGuard:
          request:
            regex:
              rules:
              - builtin: "harmful_content"
```

## 🔧 Advanced Features

### Multi-Protocol Support

- **HTTP/1.1 & HTTP/2**: Standard web protocols
- **MCP (Model Context Protocol)**: For AI agent communication
- **A2A (Agent2Agent)**: Google's agent interoperability protocol
- **WebSocket**: For real-time communication
- **gRPC**: For high-performance RPC

### Security Features

- **JWT Authentication**: Industry-standard token-based auth
- **RBAC**: Role-based access control
- **TLS Termination**: Secure connections
- **Rate Limiting**: Protect against abuse
- **CORS**: Cross-origin resource sharing

### Observability

- **Metrics**: Prometheus-compatible metrics on port 15001
- **Tracing**: OpenTelemetry distributed tracing
- **Logging**: Structured JSON logging
- **Health Checks**: Readiness probes on port 15002

### Dynamic Configuration

AgentGateway supports xDS (Discovery Service) for dynamic configuration updates:

```yaml
config:
  xdsAddress: "xds-server:18000"
  localXdsPath: "/etc/agentgateway/config"
```

## 📚 Examples

The `examples/` directory contains comprehensive examples:

- **[Basic](examples/basic/)**: Simple MCP server setup
- **[Authorization](examples/authorization/)**: JWT auth and policies
- **[TLS](examples/tls/)**: TLS termination
- **[OpenAPI](examples/openapi/)**: Legacy API transformation
- **[A2A](examples/a2a/)**: Agent-to-Agent communication
- **[Rate Limiting](examples/ratelimiting/)**: Request rate limiting
- **[Telemetry](examples/telemetry/)**: Observability setup

## 🐳 Deployment

### Docker

```bash
# Build image
make docker

# Run container
docker run -p 3000:3000 -p 15000:15000 \
  -v $(pwd)/config.yaml:/etc/agentgateway/config.yaml \
  ghcr.io/agentgateway/agentgateway:latest
```

### Kubernetes

See `manifests/` directory for Kubernetes deployment examples.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and add tests
4. Run tests: `make test`
5. Check linting: `make lint`
6. Submit a pull request

See [CONTRIBUTION.md](CONTRIBUTION.md) for detailed guidelines.

## 📖 Documentation

- **Official Docs**: [agentgateway.dev/docs](https://agentgateway.dev/docs/)
- **Architecture**: [architecture/README.md](architecture/README.md)
- **Configuration**: [schema/README.md](schema/README.md)
- **Development**: [DEVELOPMENT.md](DEVELOPMENT.md)

## 🔗 Useful Links

- **Website**: [agentgateway.dev](https://agentgateway.dev)
- **GitHub**: [github.com/agentgateway/agentgateway](https://github.com/agentgateway/agentgateway)
- **Discord**: [Join Community](https://discord.gg/BdJpzaPjHv)
- **Documentation**: [agentgateway.dev/docs](https://agentgateway.dev/docs/)

## 📄 License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## 🌟 Community

- Join our [Discord community](https://discord.gg/BdJpzaPjHv)
- Attend [community meetings](https://calendar.google.com/calendar/u/0?cid=Y18zZTAzNGE0OTFiMGUyYzU2OWI1Y2ZlOWNmOWM4NjYyZTljNTNjYzVlOTdmMjdkY2I5ZTZmNmM5ZDZhYzRkM2ZmQGdyb3VwLmNhbGVuZGFyLmdvb2dsZS5jb20)
- Watch [meeting recordings](https://drive.google.com/drive/folders/138716fESpxLkbd_KkGrUHa6TD7OA2tHs?usp=sharing)
- Star the repo on GitHub ⭐

---

*AgentGateway: The first complete connectivity solution for Agentic AI* 🚀
