
# AWS VPC Lattice Controller Deployment Guide (Terraform + Manual Steps)

## 1. Prerequisites
- AWS CLI, kubectl, helm, eksctl, jq
- EKS cluster already created

## 2. Set Environment Variables

```
export AWS_REGION=<eks_cluster_region>
export EKS_CLUSTER_NAME=<EKS_CLUSTER_NAME>
```

## 3. Install Gateway API CRDs

```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
```

## 4. Allow Traffic from Amazon VPC Lattice

Configure the EKS nodes' security group to receive traffic from the VPC Lattice network:

```
CLUSTER_SG=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region $AWS_REGION --output json | jq -r '.cluster.resourcesVpcConfig.clusterSecurityGroupId')
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists --region $AWS_REGION --query "PrefixLists[?PrefixListName=='com.amazonaws.$AWS_REGION.vpc-lattice'].PrefixListId" | jq -r '.[]')
aws ec2 authorize-security-group-ingress --group-id $CLUSTER_SG --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
PREFIX_LIST_ID_IPV6=$(aws ec2 describe-managed-prefix-lists --region $AWS_REGION --query "PrefixLists[?PrefixListName=='com.amazonaws.$AWS_REGION.ipv6.vpc-lattice'].PrefixListId" | jq -r '.[]')
aws ec2 authorize-security-group-ingress --group-id $CLUSTER_SG --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID_IPV6}}],IpProtocol=-1"
```

## 5. Set Up IAM Permissions (Terraform)

Edit variables in `main.tf` or pass via CLI:
  - `cluster_name`, `region`, `oidc_provider_arn`, `node_security_group_id`

```
cd infra/aws-vpc-lattice-controller
terraform init
terraform apply -var="cluster_name=$EKS_CLUSTER_NAME" -var="region=$AWS_REGION" -var="oidc_provider_arn=<oidc-provider-arn>" -var="node_security_group_id=$CLUSTER_SG"
```

Outputs:
- `irsa_role_arn`: Use for IRSA
- `podid_role_arn`: Use for Pod Identity

## 6. Create Namespace

```
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
```

## 7. Create Service Account

```
cat >gateway-api-controller-service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
    name: gateway-api-controller
    namespace: aws-application-networking-system
EOF
kubectl apply -f gateway-api-controller-service-account.yaml
```

## 8. Set Up Pod Identity (Recommended)

```
aws eks create-addon --cluster-name $EKS_CLUSTER_NAME --addon-name eks-pod-identity-agent --addon-version v1.0.0-eksbuild.1 --region $AWS_REGION
kubectl get pods -n kube-system | grep 'eks-pod-identity-agent'

# Create association
aws eks create-pod-identity-association --cluster-name $EKS_CLUSTER_NAME --role-arn <podid_role_arn> --namespace aws-application-networking-system --service-account gateway-api-controller --region $AWS_REGION
```

## 9. (Alternative) Set Up IRSA

```
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve --region $AWS_REGION
eksctl create iamserviceaccount \
    --cluster=$EKS_CLUSTER_NAME \
    --namespace=aws-application-networking-system \
    --name=gateway-api-controller \
    --attach-policy-arn=<irsa_policy_arn> \
    --override-existing-serviceaccounts \
    --region $AWS_REGION \
    --approve
```

## 10. Install the Controller

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

## 11. Create the GatewayClass

```
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/gatewayclass.yaml
```

---

Continue with Gateway API and Helm chart deployment as in the main README.
