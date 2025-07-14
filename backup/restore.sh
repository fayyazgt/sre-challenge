#!/bin/bash
set -e

# CONFIGURATION
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export RESTIC_PASSWORD="your-secure-password"
export RESTIC_REPOSITORY="s3:https://s3.amazonaws.com/your-bucket-name"

# TEMP LOCATION
RESTORE_TARGET="/tmp/restic-restore"
FINAL_TARGET="/data/leveldb"

echo "📦 Starting Restic restore..."
mkdir -p "$RESTORE_TARGET"

# Ensure restic is installed
if ! command -v restic &> /dev/null; then
  echo "❌ Restic not found. Please install it first."
  exit 1
fi

# List snapshots (optional)
restic snapshots

# Restore latest snapshot
restic restore latest --target "$RESTORE_TARGET"

echo "✅ Restored data to $RESTORE_TARGET"

# Copy to final mount (wipe previous data)
echo "⚠️ Wiping old data in $FINAL_TARGET..."
rm -rf "$FINAL_TARGET"/*
cp -r "$RESTORE_TARGET"/data/leveldb/* "$FINAL_TARGET"

echo "✅ Data successfully restored to $FINAL_TARGET"
