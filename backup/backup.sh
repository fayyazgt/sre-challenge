#!/bin/bash

set -e

# --- Config ---
LV_NAME="lvleveldb"
VG_NAME="vgdata"
SNAP_NAME="snap_leveldb"
MOUNT_POINT="/mnt/leveldb_snap"
RESTIC_REPO="s3:s3.amazonaws.com/your-bucket/your-path"
export RESTIC_PASSWORD="yourpassword"
export AWS_ACCESS_KEY_ID="your_aws_key"
export AWS_SECRET_ACCESS_KEY="your_aws_secret"

# --- Create snapshot ---
lvcreate -L1G -s -n $SNAP_NAME /dev/$VG_NAME/$LV_NAME

# --- Create mount point if not exists ---
mkdir -p $MOUNT_POINT

# --- Mount snapshot ---
mount /dev/$VG_NAME/$SNAP_NAME $MOUNT_POINT

# --- Run restic backup ---
restic -r $RESTIC_REPO backup $MOUNT_POINT

# --- Cleanup ---
umount $MOUNT_POINT
lvremove -f /dev/$VG_NAME/$SNAP_NAME
