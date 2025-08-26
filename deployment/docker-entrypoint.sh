#!/bin/bash

# AgentGateway Cloud Run Startup Script
# This script ensures AgentGateway starts with proper configuration for Cloud Run

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[STARTUP] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[STARTUP] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[STARTUP] $1${NC}"
}

log_error() {
    echo -e "${RED}[STARTUP] $1${NC}"
}

# Configuration paths
DEFAULT_CONFIG="/app/cloudrun-config.yaml"
CUSTOM_CONFIG="/tmp/config.yaml"

log_info "Starting AgentGateway for Cloud Run..."

# Check if Cloud Run environment
if [ -n "$PORT" ]; then
    log_info "Detected Cloud Run environment (PORT=$PORT)"
    BIND_PORT=$PORT
else
    log_info "Non-Cloud Run environment detected"
    BIND_PORT=8080
fi

# Determine which configuration to use
CONFIG_FILE=""

# Priority 1: Configuration from environment variable (base64 encoded)
if [ -n "$AGENTGATEWAY_CONFIG" ]; then
    log_info "Using configuration from AGENTGATEWAY_CONFIG environment variable"
    echo "$AGENTGATEWAY_CONFIG" | base64 -d > "$CUSTOM_CONFIG"
    CONFIG_FILE="$CUSTOM_CONFIG"
    
# Priority 2: Configuration file specified via environment
elif [ -n "$CONFIG_FILE_PATH" ] && [ -f "$CONFIG_FILE_PATH" ]; then
    log_info "Using configuration file: $CONFIG_FILE_PATH"
    CONFIG_FILE="$CONFIG_FILE_PATH"

# Priority 3: Default Cloud Run configuration
elif [ -f "$DEFAULT_CONFIG" ]; then
    log_info "Using default Cloud Run configuration: $DEFAULT_CONFIG"
    CONFIG_FILE="$DEFAULT_CONFIG"

# Fallback: No configuration (let AgentGateway use its built-in defaults)
else
    log_warning "No configuration file found, using AgentGateway built-in defaults"
fi

# Prepare AgentGateway command
AGENTGATEWAY_CMD="/app/agentgateway"

# Add configuration file if available
if [ -n "$CONFIG_FILE" ]; then
    AGENTGATEWAY_CMD="$AGENTGATEWAY_CMD --file $CONFIG_FILE"
    log_success "Configuration: $CONFIG_FILE"
else
    log_info "No configuration file, using defaults"
fi

# Log environment information
log_info "Environment Information:"
echo "  - Port: $BIND_PORT"
echo "  - Config: ${CONFIG_FILE:-"built-in defaults"}"
echo "  - Working Directory: $(pwd)"
echo "  - AgentGateway Binary: $AGENTGATEWAY_CMD"

# Show configuration content for debugging (if file exists)
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    log_info "Configuration preview:"
    head -20 "$CONFIG_FILE" | sed 's/^/  /'
    echo "  ..."
fi

# Start AgentGateway
log_success "Starting AgentGateway..."
echo ""

# Execute AgentGateway with proper configuration
exec $AGENTGATEWAY_CMD
