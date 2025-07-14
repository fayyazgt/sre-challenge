#!/bin/bash

set -e

echo "📊 Deploying Monitoring Components..."

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

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install it first."
    exit 1
fi

# Check if leveldb namespace exists
if ! kubectl get namespace leveldb &> /dev/null; then
    print_error "LevelDB namespace does not exist. Please run simple-deploy.sh first."
    exit 1
fi

print_status "Step 1: Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_status "Step 2: Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

print_status "Step 3: Installing Prometheus/Grafana stack..."
# Check if monitoring is already installed
if helm list -n monitoring | grep -q monitoring; then
    print_warning "Monitoring stack already installed. Upgrading..."
    helm upgrade monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values monitoring/values.yaml \
        --timeout 10m \
        --wait
else
    # Install monitoring stack
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --values monitoring/values.yaml \
        --timeout 10m \
        --wait
fi

print_status "Step 4: Applying Grafana configuration..."
kubectl apply -f monitoring/grafana-config.yaml

print_status "Step 5: Applying LevelDB-specific monitoring components..."
kubectl apply -f monitoring/servicemonitor.yaml
kubectl apply -f monitoring/alert-rules.yaml

print_status "Step 6: Waiting for monitoring stack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

print_status "Step 7: Verifying monitoring components..."
echo ""
echo "Monitoring Pods:"
kubectl get pods -n monitoring
echo ""
echo "Services:"
kubectl get services -n monitoring | grep -E "(grafana|prometheus)"
echo ""
echo "ServiceMonitor:"
kubectl get servicemonitor -n monitoring
echo ""
echo "PrometheusRule:"
kubectl get prometheusrule -n monitoring

print_status "✅ Monitoring components deployed successfully!"
print_status "Monitoring features enabled:"
echo "  - Prometheus for metrics collection"
echo "  - Grafana for visualization"
echo "  - ServiceMonitor for LevelDB metrics"
echo "  - Alert rules for LevelDB monitoring"
echo ""
print_status "To access monitoring:"
echo "  - Grafana: kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo "  - Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090"
echo ""
print_warning "Default Grafana credentials:"
echo "  - Username: admin"
echo "  - Password: prom-operator"
echo ""
print_status "To import LevelDB dashboard:"
echo "  - Copy content from monitoring/leveldb-grafana-dashboard.json"
echo "  - Import in Grafana dashboard" 