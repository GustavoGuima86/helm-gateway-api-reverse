#!/bin/bash

ECHO "Updating kube config"
aws eks --region eu-central-1 update-kubeconfig --name guto-cluster
ECHO "Kube config updated"

ECHO "Installing CRD"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
ECHO "CRD installed"

ECHO "Creating namespace aws-application-networking-system"
curl -o aws-application-networking-system.yaml https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-namesystem.yaml
ECHO "Namespace created"

ECHO "applying gateway-api-controller service account"
kubectl apply -f gateway-api-controller-service-account.yaml
ECHO "service account applied"

ECHO "creating pod identity association"
aws eks create-pod-identity-association \
    --cluster-name guto-cluster \
    --role-arn arn:aws:iam::156041418374:role/VPCLatticeControllerIAMRole-PodId \
    --namespace aws-application-networking-system \
    --service-account gateway-api-controller \
    --region eu-central-1 \
ECHO "pod identity association created"

ECHO "logging in to ECR"
aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws
ECHO "logged in to ECR"

ECHO "installing gateway-api-controller"
helm install gateway-api-controller \
    oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
    --version=v1.1.7 \
    --set=serviceAccount.create=false \
    --namespace aws-application-networking-system \
    --set=log.level=info
ECHO "gateway-api-controller installed"

ECHO "installing aws-application-networking-controller"
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/deploy-v1.1.7.yaml
ECHO "aws-application-networking-controller installed"

ECHO "installing gateway-classr"
kubectl apply -f https://raw.githubusercontent.com/aws/aws-application-networking-k8s/main/files/controller-installation/gatewayclass.yaml
ECHO "gateway-classr installed"

ECHO "installing gateway-api-reverse"
helm install gateway-api-reverse ../../helm/gateway-api-reverse
ECHO "gateway-api-reverse installed"