#!/bin/bash

set -e

echo "📈 Deploying Scalability Components..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

# Check if leveldb namespace exists
if ! kubectl get namespace leveldb &> /dev/null; then
    print_error "LevelDB namespace does not exist. Please run simple-deploy.sh first."
    exit 1
fi

print_status "Step 1: Creating Horizontal Pod Autoscaler (HPA)..."
kubectl apply -f scaling/hpa.yaml

print_status "Step 2: Creating Pod Disruption Budget for high availability..."
kubectl apply -f scaling/pdb.yaml

print_status "Step 3: Updating LevelDB StatefulSet with resource limits..."
# Check if we need to update the existing StatefulSet with resource limits
if kubectl get statefulset leveldb -n leveldb &> /dev/null; then
    print_warning "LevelDB StatefulSet exists, updating with resource limits..."
    kubectl patch statefulset leveldb -n leveldb --patch-file scaling/resource-limits-patch.yaml
else
    print_warning "LevelDB StatefulSet not found, resource limits will be applied when StatefulSet is created"
fi

print_status "Step 4: Waiting for components to be ready..."
# Wait for StatefulSet to be ready using a more reliable method
echo "Waiting for StatefulSet to be ready..."
timeout=300
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if kubectl get statefulset leveldb -n leveldb -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
        print_status "StatefulSet is ready!"
        break
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    echo "Waiting... ($elapsed/$timeout seconds)"
done

if [ $elapsed -ge $timeout ]; then
    print_warning "Timeout waiting for StatefulSet, but continuing..."
fi

print_status "Step 5: Verifying scalability components..."
echo ""
echo "Horizontal Pod Autoscaler:"
kubectl get hpa -n leveldb
echo ""
echo "Pod Disruption Budget:"
kubectl get pdb -n leveldb
echo ""
echo "LevelDB StatefulSet:"
kubectl get statefulset leveldb -n leveldb
echo ""
echo "Current Pods:"
kubectl get pods -n leveldb -l app=leveldb

print_status "✅ Scalability components deployed successfully!"
print_status "Scalability features enabled:"
echo "  - Horizontal Pod Autoscaler (CPU/Memory based scaling)"
echo "  - Pod Disruption Budget (high availability)"
echo "  - Resource limits and requests"
echo "  - StatefulSet for persistent storage"
echo ""
print_status "Scaling behavior:"
echo "  - Min replicas: 1"
echo "  - Max replicas: 3"
echo "  - Scale up: When CPU > 70% or Memory > 80%"
echo "  - Scale down: When CPU < 50% and Memory < 60%"
echo "  - Scale down stabilization: 5 minutes"
echo "  - Scale up stabilization: 1 minute"
echo ""
print_status "To monitor scaling:"
echo "  - kubectl get hpa -n leveldb -w"
echo "  - kubectl top pods -n leveldb"
echo "  - kubectl describe hpa leveldb-hpa -n leveldb"
echo ""
print_warning "Note: HPA requires metrics-server to be installed in your cluster" 