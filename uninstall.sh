#!/bin/bash

echo "Uninstalling Gateway API CRDs..."
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml || true
echo "Gateway API CRDs uninstalled."

echo "Uninstalling Istio components..."
helm uninstall istiod -n istio-system || true
helm uninstall istio-base -n istio-system || true
echo "Istio components uninstalled."

# Optionally delete the istio-system namespace if you want a full cleanup
# echo "Deleting istio-system namespace..."
# kubectl delete namespace istio-system || true
# echo "istio-system namespace deleted."

echo "Uninstalling backend services..."
kubectl delete -f 1-backend-services.yaml || true
echo "Backend services uninstalled."

echo "Uninstalling Gateway and Routes..."
kubectl delete -f 2-gateway-routing.yaml || true
echo "Gateway and Routes uninstalled."

echo "Uninstall complete."
