# Chart Examples

This directory contains examples of how to use the `eks-gateway-proxy` Helm chart.

## Reverse Proxy

The `reverse-proxy.yaml` file demonstrates how to set up a reverse proxy for two backend services (`service-a` and `service-b`).

### How it Works

This example creates:
1.  Two simple `Deployments` and `Services` named `service-a` and `service-b` in the `default` namespace.
2.  An `HTTPRoute` resource that attaches to the `Gateway` created by the Helm chart.

The `HTTPRoute` is configured with two rules:
-   Traffic to `http://<gateway-address>/service-a` is routed to `service-a`.
-   Traffic to `http://<gateway-address>/service-b` is routed to `service-b`.

### How to Use

1.  **Install the Helm Chart:**
    First, install the `eks-gateway-proxy` chart if you haven't already. Make sure to set your AWS-specific values as described in the main `README.md`.

    ```sh
    # From the helm-gateway-api-reverse/eks-gateway-proxy directory
    helm install my-gateway . \
      --namespace gateway-system \
      --create-namespace \
      --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/YOUR_IRSA_ROLE_NAME" \
      --set aws.region="YOUR_AWS_REGION" \
      --set aws.clusterName="YOUR_EKS_CLUSTER_NAME"
    ```

2.  **Apply the Example Manifest:**
    The `HTTPRoute` in this example needs to reference the `Gateway` created by the chart. The `reverse-proxy.yaml` manifest assumes the Helm chart was installed in the `gateway-system` namespace, as shown in the command above. If you installed it in a different namespace, you must edit the `parentRefs.namespace` field in `reverse-proxy.yaml` accordingly.

    Apply the manifest from the `examples` directory:
    ```sh
    # From the helm-gateway-api-reverse/eks-gateway-proxy/examples directory
    kubectl apply -f reverse-proxy.yaml
    ```

3.  **Test the Routes:**
    After a few moments, the AWS Gateway API controller will provision the necessary VPC Lattice resources. You can get the gateway's address from the `Gateway` resource's status.

    ```sh
    # Ensure you are targeting the correct namespace for the gateway
    GATEWAY_URL=$(kubectl get gateway my-fargate-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}')

    # Test service-a (may take a minute to become active)
    echo "Testing Service A: http://${GATEWAY_URL}/service-a"
    curl http://${GATEWAY_URL}/service-a

    # Test service-b
    echo "\nTesting Service B: http://${GATEWAY_URL}/service-b"
    curl http://${GATEWAY_URL}/service-b
    ```
