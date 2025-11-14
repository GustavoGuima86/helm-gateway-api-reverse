# Gateway API Reverse Proxy Setup

## 1. Install Gateway API CRDs

You can use Terraform (see `infra/`) or kubectl directly:

```
# Using kubectl
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml

# Or using Terraform
cd infra
curl -Lo gateway-api-crds.yaml https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
terraform init
terraform apply -var="kubeconfig_path=~/.kube/config"
```

## 2. Install Istio (Gateway Controller)

```
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system
helm install istio-ingressgateway istio/gateway -n istio-system
```

## 3. Deploy Gateway, Routes, and Test Services

```
cd ../helm
helm install gateway-api-reverse ./gateway-api-reverse
```

## 4. Test Routing

```
kubectl -n gateway-api-reverse port-forward svc/istio-ingressgateway 8080:80
curl http://localhost:8080/a
curl http://localhost:8080/b
```

You should see responses from Service A and Service B.

## 5. Clean Up

```
helm uninstall gateway-api-reverse
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

---

For AWS VPC Lattice, follow the AWS documentation to install the controller and update the GatewayClass in the Helm chart.
