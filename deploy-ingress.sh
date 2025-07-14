#!/bin/bash

set -e

echo "🌐 Deploying Ingress Components..."

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

print_status "Step 1: Checking for ingress controller..."
if ! kubectl get pods -A | grep -q ingress && ! helm list -A | grep -q traefik; then
    print_warning "No ingress controller found. Installing Traefik..."
    
    # Install Traefik using Helm if available
    if command -v helm &> /dev/null; then
        helm repo add traefik https://traefik.github.io/charts
        helm repo update
        helm install traefik traefik/traefik \
            --namespace kube-system \
            --set ingressRoute.dashboard.enabled=true \
            --timeout 5m \
            --wait
    else
        print_warning "Helm not available. Please install an ingress controller manually."
        print_warning "You can install Traefik or nginx-ingress-controller."
        exit 1
    fi
else
    print_status "Ingress controller found (Traefik already installed)."
fi

print_status "Step 2: Ensuring kube-system namespace has required labels..."
# Add required label for network policies
kubectl label namespace kube-system name=kube-system --overwrite

print_status "Step 3: Applying LevelDB ingress configuration..."
kubectl apply -f ingress/leveldb-ingress.yaml

print_status "Step 4: Waiting for ingress to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n kube-system --timeout=300s 2>/dev/null || true

print_status "Step 5: Verifying ingress components..."
echo ""
echo "Ingress:"
kubectl get ingress -n leveldb
echo ""
echo "Ingress Controller Pods:"
kubectl get pods -A | grep -E "(traefik|nginx|ingress)"
echo ""
echo "Services:"
kubectl get services -n leveldb

print_status "✅ Ingress components deployed successfully!"
print_status "Ingress features enabled:"
echo "  - External access to LevelDB API"
echo "  - TLS termination (if configured)"
echo "  - Path-based routing"
echo ""
print_warning "IMPORTANT: Update the ingress hostname in ingress/leveldb-ingress.yaml"
echo "  Replace 'leveldb.setupwp.io' with your actual domain"
echo ""
print_status "To test ingress (after updating hostname):"
echo "  - curl -H 'Host: leveldb.setupwp.io' http://YOUR_NODE_IP/write?key=test&value=data"
echo "  - curl -H 'Host: leveldb.setupwp.io' http://YOUR_NODE_IP/read?key=test"
echo ""
print_status "To get your node IP:"
echo "  kubectl get nodes -o wide" 