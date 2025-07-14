#!/bin/bash

set -e

echo "🔄 Starting Disaster Recovery Process..."

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

# Configuration
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:https://s3.amazonaws.com/your-bucket-name/leveldb-backups}"
RESTIC_PASSWORD="${RESTIC_PASSWORD:-your-secure-password}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-your-access-key}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-your-secret-key}"

# Export environment variables
export RESTIC_REPOSITORY
export RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

# Check if restic is installed
if ! command -v restic &> /dev/null; then
    print_error "Restic is not installed. Please install it first."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

print_status "Step 1: Checking restic repository connectivity..."
if ! restic snapshots &> /dev/null; then
    print_error "Cannot connect to restic repository. Check your credentials and repository URL."
    exit 1
fi

print_status "Step 2: Listing available snapshots..."
restic snapshots

print_status "Step 3: Stopping LevelDB StatefulSet..."
kubectl scale statefulset leveldb --replicas=0 -n leveldb

print_status "Step 4: Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=leveldb -n leveldb --timeout=300s || true

print_status "Step 5: Creating temporary restore directory..."
RESTORE_TEMP="/tmp/leveldb-restore-$(date +%s)"
mkdir -p "$RESTORE_TEMP"

print_status "Step 6: Restoring data from latest snapshot..."
restic restore latest --target "$RESTORE_TEMP"

print_status "Step 7: Scaling StatefulSet back to 1 replica..."
kubectl scale statefulset leveldb --replicas=1 -n leveldb

print_status "Step 8: Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=leveldb -n leveldb --timeout=300s

print_status "Step 9: Copying restored data to pod..."
POD_NAME=$(kubectl get pods -l app=leveldb -n leveldb -o jsonpath='{.items[0].metadata.name}')

# Copy restored data to the pod
kubectl cp "$RESTORE_TEMP/data/leveldb/" "leveldb/$POD_NAME:/data/leveldb/" -n leveldb

print_status "Step 10: Verifying restore..."
# Wait a moment for data to be copied
sleep 10

# Check if the application is responding
if kubectl exec -n leveldb "$POD_NAME" -- curl -f http://localhost:8080/health &> /dev/null; then
    print_status "✅ Application is responding after restore"
else
    print_warning "⚠️ Application health check failed. Please verify manually."
fi

print_status "Step 11: Cleaning up temporary files..."
rm -rf "$RESTORE_TEMP"

print_status "✅ Disaster recovery completed successfully!"
print_status "To verify the restore:"
echo "  - Check application logs: kubectl logs -n leveldb $POD_NAME"
echo "  - Test application: kubectl port-forward svc/leveldb-service -n leveldb 8080:8080"
echo "  - Verify data: curl 'http://localhost:8080/stats'" 