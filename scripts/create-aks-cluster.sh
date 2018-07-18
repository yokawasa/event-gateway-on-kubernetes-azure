#!/bin/bash
set -x -e

# For 'az aks create'
# https://docs.microsoft.com/en-us/azure/aks/create-cluster

CLUSTER_NAME="myaks-eventgateway"
KUBE_VERSION=1.9.9
RESOURCE_GROUP="rg-eventgateway"
REGION="eastus"

pip install -U azure-cli
az provider register -n Microsoft.ContainerService
az provider register -n Microsoft.Network
az provider register -n Microsoft.Compute

az group create --name $RESOURCE_GROUP --location $REGION

# Generate SSH public and private key files (~/.ssh/id_rsa, /.ssh/id_rsa.pub) if missing.
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --kubernetes-version $KUBE_VERSION \
    --generate-ssh-keys

#NODE_COUNT=3
#VM_SIZE="Standard_D1_v2"
#SSH_KEY="~/.ssh/id_rsa_nopass.pub"
#az aks create --resource-group $RESOURCE_GROUP \
#    --name $CLUSTER_NAME \
#    --kubernetes-version $KUBE_VERSION \
#    --node-vm-size $VM_SIZE \
#    --node-count $NODE_COUNT \
#    --service-principal $SP_CLIENT_ID \
#    --client-secret $SP_CLIENT_SECRET \
#    --ssh-key-value $SSH_KEY
