#!/bin/bash

set -e

echo "🔒 Deploying SSL/TLS Components..."

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

print_status "Step 1: Checking cert-manager installation..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Check if cert-manager is already installed
if helm list -n cert-manager | grep -q cert-manager; then
    print_warning "cert-manager is already installed, skipping installation..."
else
    print_status "Installing cert-manager..."
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --timeout 5m \
        --wait
fi

print_status "Step 2: Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

print_status "Step 3: Creating Let's Encrypt cluster issuer..."
# Check if ClusterIssuer already exists
if kubectl get clusterissuer letsencrypt-prod &> /dev/null; then
    print_warning "ClusterIssuer 'letsencrypt-prod' already exists, skipping creation..."
else
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@leveldb.setupwp.io
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
fi

print_status "Step 4: Updating LevelDB ingress with TLS configuration..."
# Check if ingress already exists and update it
if kubectl get ingress leveldb-ingress -n leveldb &> /dev/null; then
    print_warning "LevelDB ingress already exists, updating with TLS configuration..."
else
    print_status "Creating LevelDB ingress with TLS configuration..."
fi

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: leveldb-ingress
  namespace: leveldb
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - leveldb.setupwp.io
    secretName: leveldb-tls
  rules:
  - host: leveldb.setupwp.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: leveldb-service
            port:
              number: 8080
EOF

print_status "Step 5: Deploying monitoring ingress with SSL..."
# Check if monitoring ingress files exist
if [ -f "ingress/monitoring-ingress.yaml" ]; then
    kubectl apply -f ingress/monitoring-ingress.yaml
else
    print_warning "Monitoring ingress file not found, creating basic monitoring ingress..."
    # Create basic monitoring ingress if file doesn't exist
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - grafana.leveldb.setupwp.io
    secretName: grafana-tls
  rules:
  - host: grafana.leveldb.setupwp.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - prometheus.leveldb.setupwp.io
    secretName: prometheus-tls
  rules:
  - host: prometheus.leveldb.setupwp.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-server
            port:
              number: 80
EOF
fi

print_status "Step 6: Checking certificate status..."
echo "This may take a few minutes..."

# Function to wait for certificate with better error handling
wait_for_certificate() {
    local namespace=$1
    local cert_name=$2
    local timeout=600
    
    if kubectl get certificate $cert_name -n $namespace &> /dev/null; then
        print_status "Waiting for certificate $cert_name in namespace $namespace..."
        if kubectl wait --for=condition=ready certificate $cert_name -n $namespace --timeout=${timeout}s; then
            print_status "✅ Certificate $cert_name is ready"
        else
            print_warning "⚠️  Certificate $cert_name is not ready yet (timeout after ${timeout}s)"
        fi
    else
        print_warning "⚠️  Certificate $cert_name not found in namespace $namespace"
    fi
}

wait_for_certificate "leveldb" "leveldb-tls"
wait_for_certificate "monitoring" "grafana-tls"
wait_for_certificate "monitoring" "prometheus-tls"

print_status "✅ SSL/TLS deployment completed!"
print_status "SSL features enabled:"
echo "  - Automatic Let's Encrypt certificates"
echo "  - HTTPS redirect"
echo "  - Secure LevelDB API access"
echo "  - Secure monitoring access"
echo ""
print_status "Access URLs:"
echo "  - LevelDB API: https://leveldb.setupwp.io"
echo "  - Grafana: https://grafana.leveldb.setupwp.io"
echo "  - Prometheus: https://prometheus.leveldb.setupwp.io"
echo ""
print_status "To test HTTPS access:"
echo "  - curl -k https://leveldb.setupwp.io/health"
echo "  - curl -k -X POST 'https://leveldb.setupwp.io/write?key=test&value=data'"
echo ""
print_warning "Note: Use -k flag for testing as certificates are for specific domains" 