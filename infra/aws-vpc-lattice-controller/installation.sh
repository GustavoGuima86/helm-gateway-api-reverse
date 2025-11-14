#!/bin/bash

echo "kube config update"
aws eks --region eu-central-1 update-kubeconfig --name guto-cluster

echo "Installing CRD"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml

echo "Creating namespace aws-application-networking-system"
curl -o aws-application-networking-system.yaml https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml


# echo "creating eks addon eks-pod-identity-agent"
# aws eks create-addon --cluster-name guto-cluster --addon-name eks-pod-identity-agent --addon-version v1.0.0-eksbuild.1

# Create association
aws eks create-pod-identity-association \
    --cluster-name guto-cluster \
    --role-arn arn:aws:iam::156041418374:role/VPCLatticeControllerIAMRole-PodId \
    --namespace aws-application-networking-system \
    --service-account gateway-api-controller \
    --region eu-central-1 \

echo "applying gateway-api-controller service account"
kubectl apply -f gateway-api-controller-service-account.yaml

echo "logging in to ECR"
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws

# echo "creating Service account gateway-api-controller"
# eksctl create iamserviceaccount \
#     --cluster=guto-cluster \
#     --namespace=aws-application-networking-system \
#     --name=gateway-api-controller \
#     --attach-policy-arn=arn:aws:iam::156041418374:policy/VPCLatticeControllerIAMPolicy \
#     --override-existing-serviceaccounts \
#     --region eu-central-1 \
#     --approve



echo "installing gateway-api-controller"
helm install gateway-api-controller \
    oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
    --version=v1.1.7 \
    --set=serviceAccount.create=false \
    --namespace aws-application-networking-system \
    --set=log.level=info


echo "installing aws-application-networking-controller"
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-v1.1.7.yaml

echo "installing gateway-classr"
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/gatewayclass.yaml

echo "installing gateway-api-reverse"
helm install gateway-api-reverse ../../helm/gateway-api-reverse