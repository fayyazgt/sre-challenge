#!/bin/bash

echo "🚀 Deploying Backup Components..."

# Create namespace if it doesn't exist
kubectl create namespace leveldb --dry-run=client -o yaml | kubectl apply -f -

echo "📦 Applying Restic Secret..."
kubectl apply -f backup/restic-secret.yaml

echo "⏰ Deploying Restic Backup CronJob..."
kubectl apply -f backup/restic-backup.yaml

echo "🔄 Deploying Restore Job..."
kubectl apply -f backup/restic-restore.yaml

echo "📋 Checking deployment status..."
kubectl get cronjobs -n leveldb
kubectl get secrets -n leveldb | grep restic

echo "✅ Backup deployment completed!"
echo ""
echo "📊 To monitor backup jobs:"
echo "  kubectl get jobs -n leveldb"
echo "  kubectl logs -n leveldb job/restic-backup-<timestamp>"
echo ""
echo "🔄 To trigger a manual backup:"
echo "  kubectl create job --from=cronjob/restic-backup manual-backup -n leveldb" 