#!/bin/bash

# AgentGateway MCP Standalone Deployment Script
# This script deploys the AgentGateway MCP service to Google Cloud Run
# Region: us-east1 (updated from us-central1)

set -e

# Configuration
GCP_PROJECT_ID=${GCP_PROJECT_ID:-"orionhub-ac5cd"}
GCP_REGION="us-east1"
SERVICE_NAME="agentgateway-mcp"
ARTIFACT_REGISTRY_REPO="orion-mcp"
IMAGE_NAME="us-east1-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/agentgateway-mcp"
DEPLOY_ENV=${DEPLOY_ENV:-"production"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -d "services/web-interface" ]]; then
        log_error "services/web-interface directory not found. Please run this script from the AgentGateway project root."
        exit 1
    fi
    
    # Check for AgentGateway Dockerfile
    if [[ ! -f "services/web-interface/Dockerfile" ]]; then
        log_error "AgentGateway Dockerfile not found in services/web-interface directory."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to authenticate with Google Cloud
authenticate_gcp() {
    log_info "Authenticating with Google Cloud..."
    
    # Check if already authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log_success "Already authenticated with Google Cloud"
    else
        log_info "Please authenticate with Google Cloud..."
        gcloud auth login
    fi
    
    # Set project
    gcloud config set project ${GCP_PROJECT_ID}
    log_success "Project set to: ${GCP_PROJECT_ID}"
}

# Function to validate GCP project access
validate_gcp_access() {
    log_info "Validating GCP project access..."
    
    if gcloud projects describe ${GCP_PROJECT_ID} --quiet >/dev/null 2>&1; then
        log_success "GCP project access verified"
    else
        log_error "Cannot access GCP project: ${GCP_PROJECT_ID}"
        exit 1
    fi
    
    # Check required APIs
    log_info "Checking required APIs..."
    REQUIRED_APIS=("run.googleapis.com" "artifactregistry.googleapis.com")
    
    for api in "${REQUIRED_APIS[@]}"; do
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" --quiet | grep -q "$api"; then
            log_success "API enabled: $api"
        else
            log_warning "API not enabled: $api - attempting to enable..."
            gcloud services enable "$api"
        fi
    done
}

# Function to setup Artifact Registry
setup_artifact_registry() {
    log_info "Setting up Artifact Registry..."
    
    # Configure Docker for Artifact Registry
    gcloud auth configure-docker us-east1-docker.pkg.dev
    
    # Create repository if it doesn't exist
    if gcloud artifacts repositories describe ${ARTIFACT_REGISTRY_REPO} \
        --location=us-east1 --quiet >/dev/null 2>&1; then
        log_success "Artifact Registry repository already exists"
    else
        log_info "Creating Artifact Registry repository..."
        gcloud artifacts repositories create ${ARTIFACT_REGISTRY_REPO} \
            --repository-format=docker \
            --location=us-east1 \
            --description="Container images for AgentGateway MCP services"
        log_success "Artifact Registry repository created"
    fi
}

# Function to build and push Docker image
build_and_push_image() {
    log_info "Building and pushing AgentGateway MCP image..."
    
    # Generate image tag
    COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    IMAGE_TAG="${IMAGE_NAME}:${COMMIT_SHA}"
    LATEST_TAG="${IMAGE_NAME}:latest"
    
    # Build image
    log_info "Building Docker image..."
    cd services/web-interface
    
    docker build \
        --tag "${IMAGE_TAG}" \
        --tag "${LATEST_TAG}" \
        --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --build-arg BUILD_VERSION="${COMMIT_SHA}" \
        --build-arg BUILD_COMMIT="${COMMIT_SHA}" \
        --platform linux/amd64 \
        .
    
    log_success "Docker image built: ${IMAGE_TAG}"
    
    # Push image
    log_info "Pushing Docker image to Artifact Registry..."
    docker push "${IMAGE_TAG}"
    docker push "${LATEST_TAG}"
    
    log_success "Docker image pushed: ${IMAGE_TAG}"
    
    # Return to project root
    cd - > /dev/null
    
    # Export for deployment
    export DEPLOYMENT_IMAGE="${IMAGE_TAG}"
}

# Function to check for Context7 MCP service
check_context7_mcp() {
    log_info "Checking for Context7 MCP service (optional integration)..."
    
    if gcloud run services describe context7-mcp --region=${GCP_REGION} --quiet >/dev/null 2>&1; then
        CONTEXT7_URL=$(gcloud run services describe context7-mcp \
            --region=${GCP_REGION} \
            --format="value(status.url)")
        log_success "Found Context7 MCP at: ${CONTEXT7_URL}"
        export CONTEXT7_ENABLED=true
        export CONTEXT7_URL="${CONTEXT7_URL}"
    else
        log_info "Context7 MCP service not found - deploying without Context7 integration"
        export CONTEXT7_ENABLED=false
    fi
}

# Function to deploy to Cloud Run
deploy_to_cloud_run() {
    log_info "Deploying AgentGateway MCP to Cloud Run..."
    
    # Environment variables
    ENV_VARS="ENVIRONMENT=${DEPLOY_ENV},LOG_LEVEL=INFO,GCP_PROJECT_ID=${GCP_PROJECT_ID}"
    ENV_VARS="${ENV_VARS},MCP_TIMEOUT=60"
    
    # Add Context7 integration if available
    if [[ "${CONTEXT7_ENABLED}" == "true" ]]; then
        ENV_VARS="${ENV_VARS},CONTEXT7_MCP_URL=${CONTEXT7_URL}"
        ENV_VARS="${ENV_VARS},CONTEXT7_ENABLED=true"
        log_success "Context7 MCP integration will be enabled"
    else
        ENV_VARS="${ENV_VARS},CONTEXT7_ENABLED=false"
        log_info "Deploying without Context7 MCP integration"
    fi
    
    # Add metrics and monitoring for production
    if [[ "${DEPLOY_ENV}" == "production" ]]; then
        ENV_VARS="${ENV_VARS},ENABLE_METRICS=true"
    fi
    
    # Deploy with retry logic
    MAX_RETRIES=3
    RETRY_DELAY=30
    
    # Determine resource allocation based on environment
    if [[ "${DEPLOY_ENV}" == "production" ]]; then
        MEMORY="4Gi"
        CPU="4"
        MIN_INSTANCES="1"
        MAX_INSTANCES="20"
        CONCURRENCY="1000"
    else
        MEMORY="2Gi"
        CPU="2"
        MIN_INSTANCES="0"
        MAX_INSTANCES="10"
        CONCURRENCY="1000"
    fi
    
    attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Deployment attempt $attempt/$MAX_RETRIES..."
        
        if gcloud run deploy "${SERVICE_NAME}" \
            --image="${DEPLOYMENT_IMAGE}" \
            --platform=managed \
            --region="${GCP_REGION}" \
            --allow-unauthenticated \
            --memory="${MEMORY}" \
            --cpu="${CPU}" \
            --min-instances="${MIN_INSTANCES}" \
            --max-instances="${MAX_INSTANCES}" \
            --concurrency="${CONCURRENCY}" \
            --timeout=300 \
            --execution-environment=gen2 \
            --port=8080 \
            --set-env-vars="${ENV_VARS}" \
            --labels="environment=${DEPLOY_ENV},service=agentgateway,version=${COMMIT_SHA:-unknown}" \
            --quiet; then
            log_success "Deployment successful on attempt $attempt"
            break
        else
            log_error "Deployment failed on attempt $attempt"
            
            if [ $attempt -eq $MAX_RETRIES ]; then
                log_error "All $MAX_RETRIES deployment attempts failed!"
                exit 1
            else
                log_info "Waiting ${RETRY_DELAY}s before retry..."
                sleep $RETRY_DELAY
                RETRY_DELAY=$((RETRY_DELAY + 20))
                attempt=$((attempt + 1))
            fi
        fi
    done
}

# Function to validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --platform=managed \
        --region=${GCP_REGION} \
        --format="value(status.url)")
    
    log_info "Service URL: ${SERVICE_URL}"
    
    # Wait for service to be ready
    log_info "Waiting for service to be ready..."
    sleep 30
    
    # Health check with retries
    for i in {1..10}; do
        log_info "Health check attempt $i/10..."
        if curl -f -s --max-time 15 "${SERVICE_URL}/health" > /dev/null 2>&1; then
            log_success "Health check passed!"
            break
        else
            log_warning "Health check failed, retrying in 10s..."
            sleep 10
            if [ $i -eq 10 ]; then
                log_warning "Health check failed after 10 attempts"
                log_warning "Service may still be starting up"
            fi
        fi
    done
    
    # Test MCP discovery
    log_info "Testing MCP discovery..."
    if curl -f -s --max-time 15 "${SERVICE_URL}/mcp/" | jq . > /dev/null 2>&1; then
        log_success "MCP discovery endpoint working"
    else
        log_warning "MCP discovery endpoint not responding"
    fi
    
    # Test admin stats
    log_info "Testing admin endpoints..."
    if curl -f -s --max-time 10 "${SERVICE_URL}/admin/stats" | jq . > /dev/null 2>&1; then
        log_success "Admin stats endpoint working"
    else
        log_warning "Admin stats endpoint not responding"
    fi
    
    echo ""
    log_success "AgentGateway MCP Deployment Summary:"
    echo "- Service: ${SERVICE_NAME}"
    echo "- URL: ${SERVICE_URL}"
    echo "- Region: ${GCP_REGION}"
    echo "- Image: ${DEPLOYMENT_IMAGE}"
    echo "- Environment: ${DEPLOY_ENV}"
    echo "- Memory: ${MEMORY}, CPU: ${CPU}"
    
    if [[ "${CONTEXT7_ENABLED}" == "true" ]]; then
        echo "- Context7 MCP: ✅ Enabled (${CONTEXT7_URL})"
    else
        echo "- Context7 MCP: ℹ️ Not available"
    fi
    
    echo ""
    echo "Test Commands:"
    echo "  curl ${SERVICE_URL}/health"
    echo "  curl ${SERVICE_URL}/mcp/"
    echo "  curl ${SERVICE_URL}/admin/stats"
    
    if [[ "${CONTEXT7_ENABLED}" == "true" ]]; then
        echo ""
        echo "Context7 Integration Test:"
        echo "  curl -X POST ${SERVICE_URL}/mcp/context7/tools/search_documents \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"arguments\": {\"query\": \"test\", \"limit\": 1}}'"
    fi
}

# Function to configure service permissions
configure_permissions() {
    log_info "Configuring service permissions..."
    
    # Allow default compute service account to call this service
    DEFAULT_SA="$(gcloud iam service-accounts list --format="value(email)" --filter="displayName:Compute Engine default service account")"
    if [[ -n "${DEFAULT_SA}" ]]; then
        gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
            --member="serviceAccount:${DEFAULT_SA}" \
            --role="roles/run.invoker" \
            --region ${GCP_REGION} || log_info "Permission may already exist"
        log_success "Default service account permissions configured"
    else
        log_info "Default service account not found - services will use default permissions"
    fi
    
    # Configure permissions to call Context7 MCP if available
    if [[ "${CONTEXT7_ENABLED}" == "true" ]]; then
        gcloud run services add-iam-policy-binding context7-mcp \
            --member="serviceAccount:${DEFAULT_SA}" \
            --role="roles/run.invoker" \
            --region ${GCP_REGION} || log_info "Context7 permission may already exist"
        log_success "Context7 MCP permissions configured"
    fi
}

# Function to run integration tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --platform=managed \
        --region=${GCP_REGION} \
        --format="value(status.url)")
    
    # Test 1: Health check
    log_info "Test 1: Health check"
    if curl -f -s --max-time 10 "${SERVICE_URL}/health" | grep -q "healthy" 2>/dev/null; then
        log_success "Health check test passed"
    else
        log_warning "Health check test failed"
    fi
    
    # Test 2: MCP capabilities
    log_info "Test 2: MCP discovery"
    if curl -f -s --max-time 15 "${SERVICE_URL}/mcp/" | jq . > /dev/null 2>&1; then
        log_success "MCP discovery test passed"
    else
        log_warning "MCP discovery test failed"
    fi
    
    # Test 3: Admin stats
    log_info "Test 3: Admin stats"
    if curl -f -s --max-time 10 "${SERVICE_URL}/admin/stats" | jq . > /dev/null 2>&1; then
        log_success "Admin stats test passed"
    else
        log_warning "Admin stats test failed"
    fi
    
    # Test 4: Context7 integration (if available)
    if [[ "${CONTEXT7_ENABLED}" == "true" ]]; then
        log_info "Test 4: Context7 MCP integration"
        if curl -f -s --max-time 20 -X POST "${SERVICE_URL}/mcp/context7/tools/search_documents" \
            -H "Content-Type: application/json" \
            -d '{"arguments": {"query": "test", "limit": 1}}' | jq . > /dev/null 2>&1; then
            log_success "Context7 integration test passed"
        else
            log_warning "Context7 integration test failed (may need documents uploaded)"
        fi
    fi
    
    log_success "Integration tests completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --project-id PROJECT_ID    GCP Project ID (default: orionhub-ac5cd)"
    echo "  --environment ENV          Deployment environment (default: production)"
    echo "  --skip-build              Skip building Docker image (use existing latest)"
    echo "  --skip-tests              Skip integration tests"
    echo "  --help                    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID            GCP Project ID"
    echo "  DEPLOY_ENV                Deployment environment"
    echo ""
    echo "Environment-specific resource allocation:"
    echo "  production: 4Gi memory, 4 CPU, 1-20 instances"
    echo "  staging:    2Gi memory, 2 CPU, 0-10 instances"
    echo ""
}

# Main deployment function
main() {
    local skip_build=false
    local skip_tests=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id)
                GCP_PROJECT_ID="$2"
                shift 2
                ;;
            --environment)
                DEPLOY_ENV="$2"
                shift 2
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Update IMAGE_NAME with final project ID
    IMAGE_NAME="us-east1-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/agentgateway-mcp"
    
    log_info "Starting AgentGateway MCP deployment..."
    log_info "Project: ${GCP_PROJECT_ID}"
    log_info "Region: ${GCP_REGION}"
    log_info "Environment: ${DEPLOY_ENV}"
    
    # Run deployment steps
    check_prerequisites
    authenticate_gcp
    validate_gcp_access
    setup_artifact_registry
    
    if [[ "${skip_build}" == "false" ]]; then
        build_and_push_image
    else
        export DEPLOYMENT_IMAGE="${IMAGE_NAME}:latest"
        log_info "Skipping build, using existing image: ${DEPLOYMENT_IMAGE}"
    fi
    
    check_context7_mcp
    deploy_to_cloud_run
    configure_permissions
    validate_deployment
    
    if [[ "${skip_tests}" == "false" ]]; then
        run_integration_tests
    else
        log_info "Skipping integration tests"
    fi
    
    log_success "AgentGateway MCP deployment completed successfully! 🎉"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
