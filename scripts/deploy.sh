#!/bin/bash
# A script to deploy the entire application stack to Kubernetes.

# Exit immediately if a command exits with a non-zero status.
set -e

echo ">>> Applying base resources (Namespace)..."
kubectl apply -f k8s/base/

echo ">>> Applying Redis resources (Secret, ConfigMap, Service, StatefulSet)..."
kubectl apply -f k8s/redis/

echo ">>> Waiting for Redis to be ready..."
# Wait for the StatefulSet to be fully rolled out
kubectl wait --for=condition=ready pod -l app=redis -n tikky-app --timeout=300s

echo ">>> Applying Application resources (Deployment, Service, HPA)..."
kubectl apply -f k8s/app/

echo ">>> Applying Ingress and Network Policy resources..."
kubectl apply -f k8s/ingress/

echo "✅ Deployment complete!"
echo "It may take a minute or two for the Ingress to be fully functional."
echo "Find your Ingress IP/hostname to access the service."