
# Gateway API Reverse Proxy on EKS (with AWS VPC Lattice)

This guide provides a complete, step-by-step workflow to set up Gateway API as a reverse proxy in an EKS cluster using AWS VPC Lattice, Terraform, and Helm. It includes IAM, security group, controller, and test service setup.

---

## Prerequisites
- AWS CLI
- kubectl
- helm
- eksctl
- jq
- An existing EKS cluster

---

## 1. Set Environment Variables

```
export AWS_REGION=<eks_cluster_region>
export EKS_CLUSTER_NAME=<EKS_CLUSTER_NAME>
```

---

## 2. Install Gateway API CRDs

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

---

## 4. Set Up IAM Permissions and Security Groups (Terraform)

The Terraform in `infra/aws-vpc-lattice-controller` will automatically fetch your OIDC provider and node security group from the cluster name, and configure all required IAM and security group rules.

```
cd infra/aws-vpc-lattice-controller
terraform init
terraform apply -var="cluster_name=$EKS_CLUSTER_NAME" -var="region=$AWS_REGION"
```

Outputs:
- `irsa_role_arn`: Use for IRSA
- `podid_role_arn`: Use for Pod Identity

---

## 5. Create Namespace

```
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
```

---


## 6. Create Service Account

Apply the provided manifest:

```
kubectl apply -f infra/aws-vpc-lattice-controller/gateway-api-controller-service-account.yaml
```

---

## 7. Set Up Pod Identity (Recommended)

```
aws eks create-addon --cluster-name guto-cluster --addon-name eks-pod-identity-agent --addon-version v1.0.0-eksbuild.1 --region eu-central-1
kubectl get pods -n kube-system | grep 'eks-pod-identity-agent'

# Create association
aws eks create-pod-identity-association --cluster-name guto-cluster --role-arn arn:aws:iam::156041418374:role/VPCLatticeControllerIAMRole-PodId --namespace aws-application-networking-system --service-account gateway-api-controller --region eu-central-1
```

---


## 9. Install the AWS Gateway API Controller

### Helm (if available)
```
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws
helm install gateway-api-controller \
	oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
	--version=v1.1.7 \
	--set=serviceAccount.create=false \
	--namespace aws-application-networking-system \
	--set=log.level=info
```

### Kubectl (manifest)
```
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-v1.1.7.yaml
```

---

## 10. Create the GatewayClass

```
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/gatewayclass.yaml
```

---

## 11. Deploy Gateway and Routes (Helm)

Use the provided Helm chart in `helm/gateway-api-reverse`:

```
cd helm
helm install gateway-api-reverse ./gateway-api-reverse
```

---

## 12. Test with Two Services

The Helm chart deploys two services (`service-a` and `service-b`) and configures HTTPRoutes to route traffic based on the path (`/a` and `/b`).

To test routing, get the VPC Lattice service endpoint URL from the AWS Console or using AWS CLI. Then, curl the endpoints:

```
# Find the VPC Lattice service URL (see AWS Console > VPC Lattice > Services)
curl https://<lattice-service-endpoint>/a
curl https://<lattice-service-endpoint>/b
```

---

## 13. Clean Up

```
helm uninstall gateway-api-reverse
kubectl delete namespace aws-application-networking-system
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

---

## References

- [AWS VPC Lattice Controller Documentation](https://docs.aws.amazon.com/eks/latest/userguide/aws-vpc-lattice-controller.html)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
