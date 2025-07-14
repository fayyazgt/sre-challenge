#!/bin/bash

set -e

echo "💀 FORCE KILL CLEANUP - Aggressive Resource Termination..."

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

print_status "Step 1: SUSPENDING ALL CRONJOBS..."
# Suspend ALL cronjobs that might be creating jobs
kubectl get cronjobs -A | grep restic | awk '{print $2 " -n " $1}' | xargs -r kubectl patch -p '{"spec" : {"suspend" : true }}' 2>/dev/null || true

print_status "Step 2: FORCE KILLING ALL RUNNING PODS..."
# Force delete ALL pods in the cluster (this is aggressive!)
echo "Force killing all pods (this will restart system pods too)..."
kubectl get pods -A | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

print_status "Step 3: FORCE KILLING ALL JOBS..."
# Force delete ALL jobs in the cluster
echo "Force killing all jobs..."
kubectl get jobs -A | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

print_status "Step 4: WAITING FOR POD TERMINATION..."
# Wait a moment for pods to be killed
sleep 10

print_status "Step 5: NUCLEAR DELETION OF ALL BACKUP RESOURCES..."
# Delete all restic/leveldb resources specifically
echo "Deleting all restic backup jobs..."
kubectl get jobs -A | grep restic | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

echo "Deleting all restic backup pods..."
kubectl get pods -A | grep restic | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

echo "Deleting all restic cronjobs..."
kubectl get cronjobs -A | grep restic | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --ignore-not-found=true 2>/dev/null || true

print_status "Step 6: CLEANING UP ALL LEVELDB RESOURCES..."
# Remove all leveldb resources
kubectl delete all --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete hpa --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete pdb --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete networkpolicy --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete role --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete rolebinding --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete serviceaccount --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete cronjob --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete job --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap --all -n leveldb --ignore-not-found=true 2>/dev/null || true
kubectl delete secret --all -n leveldb --ignore-not-found=true 2>/dev/null || true

print_status "Step 7: REMOVING CLUSTER-WIDE RESOURCES..."
kubectl delete clusterrole backup-role --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding backup-rolebinding --ignore-not-found=true 2>/dev/null || true

print_status "Step 8: REMOVING STORAGE RESOURCES..."
kubectl delete pv leveldb-pv --ignore-not-found=true 2>/dev/null || true
kubectl delete storageclass local-lvm --ignore-not-found=true 2>/dev/null || true

print_status "Step 9: REMOVING MONITORING RESOURCES..."
kubectl delete servicemonitor leveldb-monitor -n monitoring --ignore-not-found=true 2>/dev/null || true
kubectl delete prometheusrule leveldb-alerts -n monitoring --ignore-not-found=true 2>/dev/null || true

print_status "Step 10: REMOVING INGRESS RESOURCES..."
kubectl delete ingress leveldb-ingress -n leveldb --ignore-not-found=true 2>/dev/null || true

print_status "Step 11: FORCE REMOVING THE NAMESPACE..."
kubectl delete namespace leveldb --ignore-not-found=true 2>/dev/null || true

print_status "Step 12: WAITING FOR NAMESPACE DELETION..."
# Wait for namespace to be fully deleted
kubectl wait --for=delete namespace/leveldb --timeout=120s 2>/dev/null || true

print_status "Step 13: FINAL AGGRESSIVE SWEEP..."
# Remove ANY remaining resources that contain leveldb or restic
echo "Final aggressive sweep for any remaining resources..."
kubectl get all -A | grep -E "(leveldb|restic)" | awk '{print $2 " -n " $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true 2>/dev/null || true

print_status "Step 14: RESTARTING KUBERNETES COMPONENTS..."
# Restart k3s to clear any stuck resources
echo "Restarting k3s service to clear stuck resources..."
sudo systemctl restart k3s 2>/dev/null || true

print_status "Step 15: WAITING FOR CLUSTER RECOVERY..."
# Wait for cluster to recover
sleep 30

print_status "✅ FORCE KILL CLEANUP COMPLETED!"
print_status "The cluster has been aggressively cleaned."
print_status "You can now run ./deploy.sh to start fresh deployment."
print_status ""
print_warning "IMPORTANT: All pods were force-killed, including system pods."
echo "  The cluster will automatically restart system components."
echo "  Wait a few minutes for the cluster to fully recover." 