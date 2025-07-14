#!/bin/bash

set -e

echo "🚀 Simple LevelDB Deployment - Core Application Only..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

print_status "Step 1: Creating namespace..."
kubectl apply -f namespace.yaml

print_status "Step 2: Creating storage components..."
kubectl apply -f storage/local-lvm-storageclass.yaml
kubectl apply -f storage/leveldb-pv.yaml

print_status "Step 3: Deploying LevelDB StatefulSet..."
kubectl apply -f app/leveldb-statefulset.yaml

print_status "Step 4: Creating scaling components..."
kubectl apply -f scaling/hpa.yaml
kubectl apply -f scaling/pdb.yaml

print_status "Step 5: Waiting for LevelDB StatefulSet to be ready..."
kubectl wait --for=condition=ready pod -l app=leveldb -n leveldb --timeout=300s

print_status "Step 6: Checking deployment status..."
kubectl get pods -n leveldb
kubectl get services -n leveldb
kubectl get pvc -n leveldb
kubectl get hpa -n leveldb

print_status "✅ Simple deployment completed successfully!"
print_status "To access the application:"
echo "  - kubectl port-forward svc/leveldb-service -n leveldb 8080:8080"
echo ""
print_status "To test the application:"
echo "  - Write: curl -X POST 'http://localhost:8080/write?key=test&value=data'"
echo "  - Read: curl 'http://localhost:8080/read?key=test'"
echo "  - Health: curl 'http://localhost:8080/health'"
echo "  - Metrics: curl 'http://localhost:8080/metrics'"
echo ""
print_warning "Note: Monitoring and backup components are not included in this simple deployment."
echo "  You can add them later once the core application is working." 