#!/bin/bash

set -e

echo "🚀 LevelDB SRE Challenge - Complete Deployment"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_warning "Helm is not installed. Some components may not work properly."
fi

if ! command -v docker &> /dev/null; then
    print_warning "Docker is not installed. Please build and push the image manually first."
fi

# Check if basic deployment exists
if ! kubectl get namespace leveldb &> /dev/null; then
    print_error "LevelDB namespace does not exist. Please run simple-deploy.sh first."
    exit 1
fi

if ! kubectl get statefulset leveldb -n leveldb &> /dev/null; then
    print_error "LevelDB StatefulSet does not exist. Please run simple-deploy.sh first."
    exit 1
fi

print_status "Prerequisites check passed!"

# Check if image exists
print_step "Checking Docker image..."
if ! docker images | grep -q "fayyazgt/leveldb-api"; then
    print_warning "Docker image not found. Please run ./build-and-push.sh first."
    print_warning "Continuing with deployment (assuming image exists in registry)..."
fi

# Deployment order
echo ""
print_step "Starting component deployment in order..."
echo ""

# 1. Security
print_step "1. Deploying Security Components..."
./deploy-security.sh
echo ""

# 2. Backup
print_step "2. Deploying Backup Components..."
./deploy-backup.sh
echo ""

# 3. Monitoring
print_step "3. Deploying Monitoring Components..."
./deploy-monitoring.sh
echo ""

# 4. Ingress
print_step "4. Deploying Ingress Components..."
./deploy-ingress.sh
echo ""

# 5. SSL/TLS
print_step "5. Deploying SSL/TLS Components..."
./deploy-ssl.sh
echo ""

# 6. Scalability
print_step "6. Deploying Scalability Components..."
./deploy-scalability.sh
echo ""

# Final verification
print_step "Final verification..."
echo ""
echo "All namespaces:"
kubectl get namespaces | grep -E "(leveldb|monitoring|cert-manager)"
echo ""
echo "All pods:"
kubectl get pods -A | grep -E "(leveldb|monitoring|cert-manager)"
echo ""
echo "All services:"
kubectl get services -A | grep -E "(leveldb|monitoring)"
echo ""

print_status "🎉 Complete deployment finished successfully!"
echo ""
print_status "Access Information:"
echo "======================"
echo "LevelDB API:"
echo "  - Internal: kubectl port-forward svc/leveldb-service -n leveldb 8080:8080"
echo "  - External HTTP: http://leveldb.setupwp.io"
echo "  - External HTTPS: https://leveldb.setupwp.io"
echo ""
echo "Monitoring:"
echo "  - Grafana: kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo "  - Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090"
echo ""
echo "Testing:"
echo "  - Write: curl -X POST 'https://leveldb.setupwp.io/write?key=test&value=data'"
echo "  - Read: curl 'https://leveldb.setupwp.io/read?key=test'"
echo "  - Health: curl 'https://leveldb.setupwp.io/health'"
echo ""
print_warning "Next steps:"
echo "  - Update Restic secret with your S3 credentials"
echo "  - Update ingress hostname with your domain"
echo "  - Import Grafana dashboard from monitoring/leveldb-grafana-dashboard.json" 