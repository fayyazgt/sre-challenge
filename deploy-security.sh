#!/bin/bash

set -e

echo "🔒 Deploying Security Components..."

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

print_status "Step 1: Applying Pod Security Policies..."
kubectl apply -f security/pod-security.yaml

print_status "Step 2: Applying Network Policies..."
kubectl apply -f security/network-policy.yaml

print_status "Step 3: Verifying security components..."
echo ""
echo "Pod Security Policies:"
kubectl get psp -A 2>/dev/null || echo "No PSP found (may not be enabled in this cluster)"
echo ""
echo "Network Policies:"
kubectl get netpol -n leveldb

print_status "✅ Security components deployed successfully!"
print_status "Security features enabled:"
echo "  - Pod Security Policies (if supported)"
echo "  - Network Policies for LevelDB namespace"
echo "  - Restricted pod execution"
echo "  - Network isolation" 