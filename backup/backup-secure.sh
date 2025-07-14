#!/bin/bash

set -e

echo "Starting secure LevelDB backup..."

# Create backup directory
mkdir -p /backup/leveldb

# Copy LevelDB data to backup directory
echo "Copying LevelDB data..."
cp -r /data/leveldb/* /backup/leveldb/ || {
    echo "Failed to copy LevelDB data"
    exit 1
}

# Initialize restic repository if not exists
echo "Initializing restic repository..."
restic init --repo $RESTIC_REPOSITORY || true

# Create backup
echo "Creating backup..."
restic backup /backup/leveldb --repo $RESTIC_REPOSITORY --verbose

# Clean up old backups (keep last 7 days)
echo "Cleaning up old backups..."
restic forget --repo $RESTIC_REPOSITORY --keep-daily 7 --prune

# Verify backup
echo "Verifying backup..."
restic check --repo $RESTIC_REPOSITORY

echo "Backup completed successfully!" 