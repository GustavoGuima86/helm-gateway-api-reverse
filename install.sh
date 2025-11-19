#!/bin/bash
ISTIO_VERSION="1.28.0"

echo "Updating kube config"
aws eks --region eu-central-1 update-kubeconfig --name guto-cluster
echo "Kube config updated"

echo "Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
echo "Gateway API CRDs installed."

echo "Adding Istio Helm repo and updating..."
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

echo "Installing Istio base..."
helm install istio-base istio/base -n istio-system --create-namespace --version $ISTIO_VERSION

echo "Installing Istiod..."
helm install istiod istio/istiod -n istio-system --version $ISTIO_VERSION
echo "Istio installed."

echo "Verifying AWS Load Balancer Controller deployment..."
kubectl get deployment -n kube-system aws-load-balancer-controller
echo "AWS Load Balancer Controller verification complete."

echo "Applying backend services..."
kubectl apply -f 1-backend-services.yaml
echo "Backend services applied."

echo "Applying Gateway and Routes..."
kubectl apply -f 2-gateway-routing.yaml
echo "Gateway and Routes applied."

echo "Waiting for Gateway URL to be assigned (up to 10 minutes)..."
for i in {1..10}; do
    GATEWAY_URL=$(kubectl get gateway public-gateway -n demo-app -o jsonpath='{.status.addresses[0].value}')
    if [ -n "$GATEWAY_URL" ]; then
        echo "Gateway URL found: $GATEWAY_URL"
        break
    fi
    echo "Attempt $i: Gateway URL not assigned yet. Waiting 1 minute..."
    sleep 1m
done

if [ -z "$GATEWAY_URL" ]; then
    echo "Error: Gateway URL was not assigned after 10 minutes."
    exit 1
fi
echo "Gateway URL: $GATEWAY_URL"

echo "Waiting for NLB to be provisioned (up to 10 minutes)..."
for i in {1..10}; do
    NLB_STATUS=$(dig +short $GATEWAY_URL | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
    if [ -n "$NLB_STATUS" ]; then
        echo "NLB is provisioned and DNS resolved: $NLB_STATUS"
        break
    fi
    echo "Attempt $i: NLB not provisioned yet. Waiting 1 minute..."
    sleep 1m
done

if [ -z "$NLB_STATUS" ]; then
    echo "Error: NLB was not provisioned after 10 minutes."
    exit 1
fi
SERVICE_A="http://$GATEWAY_URL/service-a"
SERVICE_B="http://$GATEWAY_URL/service-b"

echo "Testing $SERVICE_A route..."
curl -v $SERVICE_A
echo "Testing $SERVICE_B route..."
curl -v $SERVICE_B