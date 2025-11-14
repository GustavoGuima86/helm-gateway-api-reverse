# EKS Gateway Proxy Helm Chart

This Helm chart deploys the [AWS Gateway API Controller](https://docs.aws.amazon.com/vpc-lattice/latest/ug/gateway-api-controller.html) to an Amazon EKS cluster. The controller manages AWS VPC Lattice services and network resources based on the Kubernetes Gateway API.

This chart is configured to be suitable for EKS clusters running in Fargate mode.

## How it Works

The chart provisions the following Kubernetes resources:

*   **`ServiceAccount`**: A dedicated service account for the AWS Gateway API Controller pod. It is annotated to use AWS IAM Roles for Service Accounts (IRSA) for authenticating with the AWS API.
*   **`Deployment`**: Runs the AWS Gateway API Controller. The controller pod is configured with the necessary arguments to communicate with the AWS API, including the AWS region and EKS cluster name.
*   **`GatewayClass`**: A cluster-scoped resource that defines a class of Gateways that can be provisioned. This chart creates a `GatewayClass` named `aws-vpc-lattice`.
*   **`Gateway`**: A namespaced resource that requests a traffic routing entrypoint. This chart creates a `Gateway` that listens for HTTP traffic on port 80.
*   **`HTTPRoute`**: A namespaced resource that defines rules for routing HTTP traffic from a `Gateway` to backend services. This chart provides a sample route for `api.example.com` to a backend service.

## Prerequisites

*   Kubernetes 1.25+
*   Helm 3.2.0+
*   An active Amazon EKS cluster.
*   An IAM OIDC provider configured for the EKS cluster to allow for IAM Roles for Service Accounts (IRSA).
*   An IAM Role for the AWS Gateway API Controller with the required permissions. The trust policy for the role must allow the `ServiceAccount` created by this chart to assume it.

## Installation

1.  **Navigate to the chart directory:**
    ```sh
    cd eks-gateway-proxy
    ```

2.  **Package the Chart:**
    This command packages the chart into a versioned archive file.
    ```sh
    helm package .
    ```

3.  **Install the Chart:**
    To install the chart with the release name `my-gateway`, run the following command. You must override key values with your environment-specific details.

    *   `serviceAccount.annotations."eks\.amazonaws\.com/role-arn"`: The ARN of the IAM role you created for the controller.
    *   `aws.region`: The AWS region your EKS cluster is in.
    *   `aws.clusterName`: The name of your EKS cluster.

    ```sh
    helm install my-gateway ./eks-gateway-proxy-0.1.0.tgz \
      --namespace gateway-system \
      --create-namespace \
      --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/YOUR_IRSA_ROLE_NAME" \
      --set aws.region="YOUR_AWS_REGION" \
      --set aws.clusterName="YOUR_EKS_CLUSTER_NAME"
    ```

## Configuration

The following table lists the most important configurable parameters of the `eks-gateway-proxy` chart and their default values.

| Parameter                                    | Description                                                                                             | Default                                                              | 
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | 
| `replicaCount`                               | Number of replicas for the controller deployment.                                                       | `1`                                                                  | 
| `image.repository`                           | The container image repository for the AWS Gateway API Controller.                                      | `public.ecr.aws/aws-application-networking-k8s/aws-gateway-api-controller` | 
| `image.tag`                                  | The container image tag.                                                                                | `"v1.0.4"`                                                           | 
| `aws.region`                                 | The AWS region where the EKS cluster is running.                                                        | `"us-west-2"`                                                        | 
| `aws.clusterName`                            | The name of your EKS cluster.                                                                           | `"my-eks-cluster"`                                                   | 
| `serviceAccount.create`                      | Whether to create a service account.                                                                    | `true`                                                               | 
| `serviceAccount.annotations`                 | Annotations for the service account. **Must be overridden** with your IRSA role ARN.                    | `{ "eks.amazonaws.com/role-arn": "..." }`                            | 
| `gateway.name`                               | Name of the Gateway resource.                                                                           | `"my-fargate-gateway"`                                               | 
| `gateway.listener.port`                      | The port on which the Gateway listens.                                                                  | `80`                                                                 | 
| `httpRoute.hostname`                         | The hostname to match for the HTTPRoute.                                                                | `"api.example.com"`                                                  | 
| `httpRoute.backend.service.name`             | The name of the backend service to route traffic to.                                                    | `"my-application-service"`                                           | 
| `httpRoute.backend.service.namespace`        | The namespace of the backend service.                                                                   | `"default"`                                                          | 
| `httpRoute.backend.service.port`             | The port of the backend service.                                                                        | `8080`                                                               |