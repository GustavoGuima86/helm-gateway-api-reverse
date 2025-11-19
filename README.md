# Helm Gateway API Reverse Proxy Example

This project demonstrates how to set up a reverse proxy using Kubernetes Gateway API and Istio, routing traffic to two backend services (`service-a` and `service-b`). It's designed to be deployed on an AWS EKS cluster with the AWS Load Balancer Controller already installed.

## Project Structure

*   `1-backend-services.yaml`: Defines the `demo-app` namespace, and two NGINX-based backend services (`service-a` and `service-b`) along with their Kubernetes Deployments and Services.
*   `2-gateway-routing.yaml`: Configures the Kubernetes Gateway API resources. This includes a `Gateway` resource that provisions an AWS Network Load Balancer (NLB) via annotations, and an `HTTPRoute` that defines routing rules to direct traffic to `service-a` and `service-b` based on URL paths (`/service-a` and `/service-b`).
*   `install.sh`: A bash script to deploy the entire setup, including Gateway API CRDs, Istio (base and Istiod), backend services, and gateway routing rules. It also waits for the Gateway URL and NLB provisioning, and then tests the routes.
*   `uninstall.sh`: A bash script to tear down all the resources created by `install.sh`.

## Prerequisites

Before deploying this project, ensure you have the following:

1.  **AWS EKS Cluster:** An existing Amazon EKS cluster.
2.  **`kubectl`:** Configured to connect to your EKS cluster. The `install.sh` script will update your kubeconfig for a specific cluster (`guto-cluster` in `eu-central-1`).
3.  **`helm`:** The Kubernetes package manager.
4.  **AWS Load Balancer Controller:** This controller must be installed and running in your EKS cluster. The `Gateway` resource uses annotations that rely on this controller to provision the NLB.
5.  **`aws-cli`:** Configured with appropriate credentials to interact with your AWS account.
6.  **`dig`:** A DNS lookup utility (usually part of `dnsutils` or `bind-utils` packages) for verifying NLB provisioning.
7.  **`curl`:** For testing the deployed services.

## Deployment

To deploy the project, execute the `install.sh` script:

```bash
./install.sh
```

This script will perform the following actions:

1.  Update your `kubeconfig` to connect to the specified EKS cluster.
2.  Install the Gateway API Custom Resource Definitions (CRDs).
3.  Add the Istio Helm repository and install Istio base and Istiod.
4.  Verify the presence of the AWS Load Balancer Controller.
5.  Apply the backend service deployments and services.
6.  Apply the Gateway API `Gateway` and `HTTPRoute` resources.
7.  Wait for the AWS NLB to be provisioned and its URL to be available.
8.  Test the `/service-a` and `/service-b` routes using `curl`.

## Testing

After successful deployment, the `install.sh` script will automatically test the routes and print the `curl` output. You can manually test the services by getting the Gateway URL and then accessing the paths:

1.  Get the Gateway URL:
    ```bash
    kubectl get gateway public-gateway -n demo-app -o jsonpath='{.status.addresses[0].value}'
    ```
2.  Access `service-a`:
    ```bash
    curl http://<YOUR_GATEWAY_URL>/service-a
    ```
3.  Access `service-b`:
    ```bash
    curl http://<YOUR_GATEWAY_URL>/service-b
    ```

You should see "Hello from service-a" and "Hello from service-b" respectively.

## Cleanup

To remove all the deployed resources, execute the `uninstall.sh` script:

```bash
./uninstall.sh
```

This script will delete:

*   Gateway API CRDs
*   Istio components (istiod, istio-base)
*   Backend services (deployments, services, and the `demo-app` namespace)
*   Gateway API `Gateway` and `HTTPRoute` resources.
