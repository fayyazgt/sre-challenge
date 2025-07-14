#!/bin/bash

echo "🔨 Building and pushing LevelDB Docker image..."

# Set variables
IMAGE_NAME="fayyazgt/leveldb-api"
TAG="latest"

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME:$TAG app/

# Push the image
echo "Pushing Docker image..."
docker push $IMAGE_NAME:$TAG

echo "✅ Docker image built and pushed successfully!"
echo "Image: $IMAGE_NAME:$TAG"
echo ""
echo "Now restart the LevelDB pod to use the new image:"
echo "kubectl delete pod leveldb-0 -n leveldb" 