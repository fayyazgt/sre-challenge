#!/bin/bash

echo "🔍 Verifying Nuclear Cleanup Results..."

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

echo ""
print_status "Checking for remaining leveldb/restic resources..."

# Check for any remaining resources
REMAINING_RESOURCES=$(kubectl get all -A | grep -E "(leveldb|restic)" | wc -l)
REMAINING_JOBS=$(kubectl get jobs -A | grep restic | wc -l)
REMAINING_PODS=$(kubectl get pods -A | grep restic | wc -l)
REMAINING_CRONJOBS=$(kubectl get cronjobs -A | grep restic | wc -l)
NAMESPACE_EXISTS=$(kubectl get namespace leveldb 2>/dev/null | wc -l)

echo ""
echo "=== CLEANUP VERIFICATION RESULTS ==="
echo "Remaining leveldb/restic resources: $REMAINING_RESOURCES"
echo "Remaining restic jobs: $REMAINING_JOBS"
echo "Remaining restic pods: $REMAINING_PODS"
echo "Remaining restic cronjobs: $REMAINING_CRONJOBS"
echo "LevelDB namespace exists: $NAMESPACE_EXISTS"

echo ""
if [ "$REMAINING_RESOURCES" -eq 0 ] && [ "$REMAINING_JOBS" -eq 0 ] && [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_CRONJOBS" -eq 0 ] && [ "$NAMESPACE_EXISTS" -eq 0 ]; then
    print_status "✅ NUCLEAR CLEANUP SUCCESSFUL!"
    print_status "All leveldb and restic resources have been removed."
    print_status "You can now run ./deploy.sh for fresh deployment."
else
    print_warning "⚠️  Some resources still remain:"
    
    if [ "$REMAINING_RESOURCES" -gt 0 ]; then
        echo "  - $REMAINING_RESOURCES leveldb/restic resources found"
        kubectl get all -A | grep -E "(leveldb|restic)"
    fi
    
    if [ "$REMAINING_JOBS" -gt 0 ]; then
        echo "  - $REMAINING_JOBS restic jobs found"
        kubectl get jobs -A | grep restic
    fi
    
    if [ "$REMAINING_PODS" -gt 0 ]; then
        echo "  - $REMAINING_PODS restic pods found"
        kubectl get pods -A | grep restic
    fi
    
    if [ "$REMAINING_CRONJOBS" -gt 0 ]; then
        echo "  - $REMAINING_CRONJOBS restic cronjobs found"
        kubectl get cronjobs -A | grep restic
    fi
    
    if [ "$NAMESPACE_EXISTS" -gt 0 ]; then
        echo "  - LevelDB namespace still exists"
    fi
    
    echo ""
    print_error "Run the nuclear cleanup again or manually delete remaining resources."
fi

echo ""
print_status "Current cluster state:"
echo "Total resources in cluster:"
kubectl get all -A | wc -l
echo "Namespaces:"
kubectl get namespaces 