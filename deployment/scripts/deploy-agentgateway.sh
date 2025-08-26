#!/bin/bash

# Official AgentGateway Deployment Script
# Deploys the official Rust AgentGateway binary to Google Cloud Run
# Region: us-east1

set -e

# Configuration
GCP_PROJECT_ID=${GCP_PROJECT_ID:-"orionhub-ac5cd"}
GCP_REGION="us-east1"
SERVICE_NAME="agentgateway"
ARTIFACT_REGISTRY_REPO="agentgateway"
IMAGE_NAME="us-east1-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/agentgateway"
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
    
    # Check if we're in the right directory (AgentGateway root)
    if [[ ! -f "Dockerfile" ]] || [[ ! -f "Cargo.toml" ]] || [[ ! -d "ui" ]]; then
        log_error "Not in AgentGateway project root. Please run from the repository root directory."
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
    REQUIRED_APIS=("run.googleapis.com" "artifactregistry.googleapis.com" "cloudbuild.googleapis.com")
    
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
            --description="Container images for official AgentGateway"
        log_success "Artifact Registry repository created"
    fi
}

# Function to build and push Docker image
build_and_push_image() {
    log_info "Building and pushing official AgentGateway image..."
    
    # Generate image tag
    COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    IMAGE_TAG="${IMAGE_NAME}:${COMMIT_SHA}"
    LATEST_TAG="${IMAGE_NAME}:latest"
    
    # Build image using the official Dockerfile
    log_info "Building Docker image with official Rust AgentGateway..."
    docker build \
        --tag "${IMAGE_TAG}" \
        --tag "${LATEST_TAG}" \
        --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --build-arg BUILD_VERSION="${COMMIT_SHA}" \
        --platform linux/amd64 \
        .
    
    log_success "Docker image built: ${IMAGE_TAG}"
    
    # Push image
    log_info "Pushing Docker image to Artifact Registry..."
    docker push "${IMAGE_TAG}"
    docker push "${LATEST_TAG}"
    
    log_success "Docker image pushed: ${IMAGE_TAG}"
    
    # Export for deployment
    export DEPLOYMENT_IMAGE="${IMAGE_TAG}"
}

# Function to create AgentGateway configuration
create_agentgateway_config() {
    log_info "Creating AgentGateway configuration for Cloud Run..."
    
    # Create Cloud Run compatible configuration
    # Cloud Run expects service to listen on PORT environment variable (8080)
    cat > /tmp/agentgateway-config.yaml << EOF
config:
  # Cloud Run configuration - all services on port 8080
  adminAddr: "0.0.0.0:8080"    # Cloud Run traffic port
  statsAddr: "0.0.0.0:8081"    # Internal metrics
  readinessAddr: "0.0.0.0:8082" # Internal health
  workerThreads: 4

binds:
- port: 8080  # Cloud Run PORT
  listeners:
  - protocol: HTTP
    routes:
    - name: health-check
      matches:
      - path:
          pathPrefix: /health
      policies:
        directResponse:
          body: "AgentGateway is healthy"
          status: 200
    
    - name: ui-route
      matches:
      - path:
          pathPrefix: /ui
      policies:
        directResponse:
          body: "AgentGateway UI available"
          status: 200
    
    - name: admin-route
      matches:
      - path:
          pathPrefix: /admin
      policies:
        directResponse:
          body: "Admin interface available"
          status: 200
    
    - name: stats-route
      matches:
      - path:
          pathPrefix: /stats
      policies:
        directResponse:
          body: "Metrics available"
          status: 200
    
    - name: mcp-route
      matches:
      - path:
          pathPrefix: /mcp
      policies:
        directResponse:
          body: "MCP endpoints available"
          status: 200
    
    - name: default-route
      matches:
      - path:
          pathPrefix: /
      policies:
        directResponse:
          body: |
            🤖 Official AgentGateway
            
            Available endpoints:
            - /health - Health check
            - /ui - Web interface  
            - /admin - Admin interface
            - /stats - Metrics
            - /mcp - MCP protocol endpoints
            
            This is the official Rust implementation on Cloud Run.
          status: 200
EOF

    log_success "Cloud Run AgentGateway configuration created"
}

# Function to check for existing orion services
check_orion_services() {
    log_info "Checking for orion services integration..."
    
    # Check for orionOrchestrator
    if gcloud run services describe orion-orchestrator --region=${GCP_REGION} --quiet >/dev/null 2>&1; then
        ORCHESTRATOR_URL=$(gcloud run services describe orion-orchestrator \
            --region=${GCP_REGION} \
            --format="value(status.url)")
        log_success "Found orionOrchestrator at: ${ORCHESTRATOR_URL}"
        export ORCHESTRATOR_URL="${ORCHESTRATOR_URL}"
        export ORCHESTRATOR_ENABLED=true
    else
        log_info "orionOrchestrator service not found"
        export ORCHESTRATOR_ENABLED=false
    fi
    
    # Check for orionCreate
    if gcloud run services describe orion-create --region=${GCP_REGION} --quiet >/dev/null 2>&1; then
        CREATE_URL=$(gcloud run services describe orion-create \
            --region=${GCP_REGION} \
            --format="value(status.url)")
        log_success "Found orionCreate at: ${CREATE_URL}"
        export CREATE_URL="${CREATE_URL}"
        export CREATE_ENABLED=true
    else
        log_info "orionCreate service not found"
        export CREATE_ENABLED=false
    fi
}

# Function to deploy to Cloud Run
deploy_to_cloud_run() {
    log_info "Deploying official AgentGateway to Cloud Run..."
    
    # Environment variables
    ENV_VARS="ENVIRONMENT=${DEPLOY_ENV},LOG_LEVEL=INFO,GCP_PROJECT_ID=${GCP_PROJECT_ID}"
    ENV_VARS="${ENV_VARS},RUST_LOG=info"
    
    # Use built-in container configuration (no override needed)
    log_info "Using built-in Cloud Run configuration from container"
    
    # Add orion service integration if available
    if [[ "${ORCHESTRATOR_ENABLED}" == "true" ]]; then
        ENV_VARS="${ENV_VARS},ORCHESTRATOR_URL=${ORCHESTRATOR_URL}"
        ENV_VARS="${ENV_VARS},ORCHESTRATOR_ENABLED=true"
    else
        ENV_VARS="${ENV_VARS},ORCHESTRATOR_ENABLED=false"
    fi
    
    if [[ "${CREATE_ENABLED}" == "true" ]]; then
        ENV_VARS="${ENV_VARS},CREATE_URL=${CREATE_URL}"
        ENV_VARS="${ENV_VARS},CREATE_ENABLED=true"
    else
        ENV_VARS="${ENV_VARS},CREATE_ENABLED=false"
    fi
    
    # Resource allocation based on environment
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
    
    # Deploy with retry logic
    MAX_RETRIES=3
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
            --labels="environment=${DEPLOY_ENV},service=agentgateway,type=official,version=${COMMIT_SHA:-unknown}" \
            --quiet; then
            log_success "Deployment successful on attempt $attempt"
            break
        else
            log_error "Deployment failed on attempt $attempt"
            
            if [ $attempt -eq $MAX_RETRIES ]; then
                log_error "All $MAX_RETRIES deployment attempts failed!"
                exit 1
            else
                log_info "Waiting 30s before retry..."
                sleep 30
                attempt=$((attempt + 1))
            fi
        fi
    done
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
    fi
    
    # Configure permissions for orion services integration
    if [[ "${ORCHESTRATOR_ENABLED}" == "true" ]] && [[ -n "${DEFAULT_SA}" ]]; then
        gcloud run services add-iam-policy-binding orion-orchestrator \
            --member="serviceAccount:${DEFAULT_SA}" \
            --role="roles/run.invoker" \
            --region ${GCP_REGION} || log_info "Orchestrator permission may already exist"
        log_success "orionOrchestrator integration permissions configured"
    fi
    
    if [[ "${CREATE_ENABLED}" == "true" ]] && [[ -n "${DEFAULT_SA}" ]]; then
        gcloud run services add-iam-policy-binding orion-create \
            --member="serviceAccount:${DEFAULT_SA}" \
            --role="roles/run.invoker" \
            --region ${GCP_REGION} || log_info "Create permission may already exist"
        log_success "orionCreate integration permissions configured"
    fi
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
    
    # Test admin endpoints
    log_info "Testing admin endpoints..."
    if curl -f -s --max-time 10 "${SERVICE_URL}/admin" > /dev/null 2>&1; then
        log_success "Admin endpoint working"
    else
        log_warning "Admin endpoint not responding"
    fi
    
    # Test UI endpoint
    log_info "Testing UI endpoint..."
    if curl -f -s --max-time 10 "${SERVICE_URL}/ui" > /dev/null 2>&1; then
        log_success "UI endpoint working"
    else
        log_warning "UI endpoint not responding"
    fi
    
    echo ""
    log_success "Official AgentGateway Deployment Summary:"
    echo "- Service: ${SERVICE_NAME}"
    echo "- URL: ${SERVICE_URL}"
    echo "- Region: ${GCP_REGION}"
    echo "- Image: ${DEPLOYMENT_IMAGE}"
    echo "- Environment: ${DEPLOY_ENV}"
    echo "- Memory: ${MEMORY}, CPU: ${CPU}"
    echo "- Admin UI: ${SERVICE_URL}/ui"
    echo "- Health Check: ${SERVICE_URL}/health"
    
    if [[ "${ORCHESTRATOR_ENABLED}" == "true" ]]; then
        echo "- orionOrchestrator: ✅ Integrated (${ORCHESTRATOR_URL})"
    else
        echo "- orionOrchestrator: ℹ️ Not found"
    fi
    
    if [[ "${CREATE_ENABLED}" == "true" ]]; then
        echo "- orionCreate: ✅ Integrated (${CREATE_URL})"
    else
        echo "- orionCreate: ℹ️ Not found"
    fi
    
    echo ""
    echo "Test Commands:"
    echo "  curl ${SERVICE_URL}/health"
    echo "  curl ${SERVICE_URL}/ui"
    echo "  curl ${SERVICE_URL}/admin"
    echo "  open ${SERVICE_URL}/ui"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --project-id PROJECT_ID    GCP Project ID (default: orionhub-ac5cd)"
    echo "  --environment ENV          Deployment environment (default: production)"
    echo "  --skip-build              Skip building Docker image (use existing latest)"
    echo "  --skip-tests              Skip health checks"
    echo "  --help                    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID            GCP Project ID"
    echo "  DEPLOY_ENV                Deployment environment"
    echo ""
    echo "This deploys the official Rust AgentGateway with:"
    echo "  - Built-in Next.js web UI"
    echo "  - Admin endpoints on port 15000"
    echo "  - Traffic endpoints on port 8080"
    echo "  - Integration with orion services (if available)"
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
    IMAGE_NAME="us-east1-docker.pkg.dev/${GCP_PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/agentgateway"
    
    log_info "Starting Official AgentGateway deployment..."
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
    
    create_agentgateway_config
    check_orion_services
    deploy_to_cloud_run
    configure_permissions
    
    if [[ "${skip_tests}" == "false" ]]; then
        validate_deployment
    else
        log_info "Skipping health checks"
    fi
    
    log_success "Official AgentGateway deployment completed successfully! 🎉"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
