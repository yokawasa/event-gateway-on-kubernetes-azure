# Serverless Event Gateway on Kubernetes (Azure)
How to guide on running Serverless.com's [Event Gateway](https://github.com/serverless/event-gateway) on Kubernetes (Azure Version). This is derived from Kelsey Hightower's [Serverless Event Gateway on Kubernetes](https://github.com/kelseyhightower/event-gateway-on-kubernetes) to use Azure. Kelsey's original tutorial is based on GCP.

## Prerequisites
### Azure Subscription
This tutorial assumes you have [Azure Subscription](https://azure.microsoft.com/en-us/) to deploy into.

### Azure CLI

In this tutorial, you need azure-cli command line tool to run this workthrough.
Suppose you want to operate locally and you don't yet have azure-cli installed on your local environment, you can install the azure-cli like this:

```
sudo pip install -U azure-cli
```

You can skip this installation if you're running this workthrough on [Azure Cloud Shell Bash](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) where the azure-cli is pre-installed.

![](images/azure-cloud-shell-bash.png)

## Tutorial

* [Creating a Kubernetes Cluster(AKS)](#creating-a-kubernetes-cluster-aks)
* [Bootstrapping an Event Gateway Cluster](#bootstrapping-an-event-gateway-cluster)
* [Routing Events to Azure Functions](#routing-events-to-azure-functions)
* [Routing Events to Kubernetes Services](#routing-events-to-kubernetes-services)
* [Clean Up](#clean-up)


## Creating a Kubernetes Cluster (AKS)

First of all, execute the following commands which are needed in case that it's the first time to manage network & compute resources with your subscription:
```sh
$ az provider register -n Microsoft.Network
$ az provider register -n Microsoft.Compute
```

### Create Resource Group for the tutorial

```sh
$ az group create --name rg-eventgateway --location eastus
```
> [note] This tutorial assumes that you create the resource group named `rg-eventgateway` in `eastus` region
> 

### Create an AKS cluster

The remainder of this tutorial requires access to a Kubernetes `1.9.7+` cluster

```
$ az aks create \
    --resource-group rg-eventgateway \
    --name myaks-eventgateway \
    --kubernetes-version 1.9.9 \
    --generate-ssh-keys

```
> - [note1] This tutorial assumes that you create the AKS cluster named `myaks-eventgateway` under the resource group named `rg-eventgateway`
> - [note2] SSH key files `$HOME/.ssh/id_rsa` and `$HOME/.ssh/id_rsa.pub` have been generated under ~/.ssh to allow SSH access to the VM. If using machines without permanent storage like Azure Cloud Shell without an attached file share, back up your keys to a safe location
> - If you already have a ssh key generated and you want to use it instead of generating new key, specify your SSH key with `--ssh-key-value` option instead of `--generate-ssh-keys` in creating AKS Cluster. Please see [azure CLI command reference](https://docs.microsoft.com/en-us/azure/aks/create-cluster) for az aks create for more details 

### Install the kubectl CLI and connect to the cluster with kubectl

If you want to install kubectl CLI locally, run the following command:
```sh
$ az aks install-cli
```
> [note] You can skip this installation if you're running this workthrough on [Azure Cloud Shell Bash](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) where the kubeclt is pre-installed.

Run the following command to configure kubectl to connect to your Kubernetes cluster, run the following command:
```
$ az aks get-credentials --resource-group=rg-eventgateway --name=myaks-eventgateway 
```

Finally, check if you can connect to the cluster by running the following command:
```sh
$ kubectl get nodes

NAME                       STATUS    ROLES     AGE       VERSION
aks-nodepool1-97802812-0   Ready     agent     14m       v1.9.9
aks-nodepool1-97802812-1   Ready     agent     14m       v1.9.9
aks-nodepool1-97802812-2   Ready     agent     14m       v1.9.9
```

## Bootstrapping an Event Gateway Cluster

In this section you will bootstrap a two node Event Gateway cluster suitable for learning and demonstration purposes.

> The Event Gateway configuration used in this tutorial is not recommended for production as it lacks any form of security or authentication.

### Create an etcd Cluster

etcd is used to store and broadcast configuration across an Event Gateway cluster. A dedicated etcd cluster should be provisioned for the Event Gateway. Create the `etcd` statefulset:

```sh
$ kubectl apply -f statefulsets/etcd.yaml

statefulset "etcd" created
service "etcd" created
```

Verify the `etcd` cluster is up and running:

```sh
$ kubectl get pods

NAME      READY     STATUS    RESTARTS   AGE
etcd-0    1/1       Running   0          20s
```

### Create an Event Gateway Cluster

Create the `event-gateway` deployment:

```sh
$ kubectl apply -f deployments/event-gateway.yaml

deployment "event-gateway" created
service "event-gateway" created
```

At this point the Event Gateway should be deployed and exposed via an external load balancer accessible to external clients. Verify the Event Gateway is up and running:

```sh
$ kubectl get pods

NAME                             READY     STATUS    RESTARTS   AGE
etcd-0                           1/1       Running   0          12m
event-gateway-5ff8554766-jhs6v   1/1       Running   0          4m
event-gateway-5ff8554766-jpmwp   1/1       Running   0          4m
```

Print the `event-gateway` service details:

```
$ kubectl get svc event-gateway

NAME            TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                         AGE
event-gateway   LoadBalancer   10.0.112.249   XX.XXX.XXX.XX   4000:30152/TCP,4001:30426/TCP   5m
```

Extract the `event-gateway` external IP address and store it:

```sh
export EVENT_GATEWAY_IP=$(kubectl get svc event-gateway \
-o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo $EVENT_GATEWAY_IP
```

## Routing Events to Azure Functions

In this section you will deploy the `echo` Function in Azure Functions used to test the event routing functionality of the Event Gateway. 
> Sample `echo` function that is used in this tutorial is not recommended for production as it lacks any form of security or authentication (authLevel is `anonymous`).

### Deploy echo function in Azure Function

Deploy the `echo` function in Azure Function by executing `scripts/deploy-function.sh`. Before executing the script, you need to add globally unique Azure Function acccount name and Azure Storage account name to `FUNCTION_NAME` and `STORAGE_NAME` variable respectively.

```sh
#!/bin/bash
set -x -e

cwd=`dirname "$0"`
expr "$0" : "/.*" > /dev/null || cwd=`(cd "$cwd" && pwd)`

RESOURCE_GROUP="rg-eventgateway"
REGION="eastus"
FUNCTION_NAME="myazfunc001"
STORAGE_NAME="myazfuncstore001"

## Create Storage Account for Azure Function
echo "Create Storage Account for Azure Function..."
az storage account create \
    --name $STORAGE_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Standard_LRS \
    --kind Storage

## Create Functions App (Consumption Plan)
echo "Create Functions App (Consumption Plan)..."
az functionapp create \
    --name $FUNCTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --consumption-plan-location $REGION \
    --storage-account $STORAGE_NAME

## Deploying functions
echo "Deploying functions..."
cd $cwd/../functions
zip -r functions.zip .
az functionapp deployment source config-zip  --name $FUNCTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --src functions.zip
rm functions.zip
echo "echo function URL: https://$FUNCTION_NAME.azurewebsites.net/api/echo"
```
> [note] This tutorial assumes that you create the Azure Function account named `myazfunc001` and Azure Storage account named `myazfuncstore001` under the resource group named `rg-eventgateway` whichi is located in `eastus` region. Again, both Azure Function account name and Storage account name must be globally unique. 

Then, execute the script, `scripts/deploy-function.sh` to deploy the `echo` function in Azure Function:
```sh
$ scripts/deploy-function.sh
```

Get the HTTPS URL assigned to the `echo` function and store it to `FUNCTION_URL` enviroment variable:

```
export FUNCTION_URL="https://${FUNCTION_NAME}.azurewebsites.net/api/echo"
```

The `FUNCTION_URL` environment variable will be used in the next section to register the `echo` cloud function with the Event Gateway.

### Register the echo Function with the Event Gateway

In this section you will register the `echo` cloud function with the Event Gateway.

Register the `echo` cloud function by posting the function registration object to the Event Gateway:

```sh
curl --request POST \
  --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/functions \
  --header 'content-type: application/json' \
  --data "{
    \"functionId\": \"echo\",
    \"type\": \"http\",
    \"provider\":{
        \"url\": \"${FUNCTION_URL}\"
    }
}"
```

At this point the `echo` function has been registered with the Event Gateway, but before it can receive events a subscription must be created.

### Create a Subscription

A [subscription](https://github.com/serverless/event-gateway#subscriptions) binds an event to a function. In this section you will create an HTTP event subscription that binds the `echo` cloud function to HTTP events received on the `POST` method and the `/` path pair:

```sh
curl --request POST \
  --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/subscriptions \
  --header 'content-type: application/json' \
  --data '{
    "functionId": "echo",
    "event": "http",
    "method": "POST",
    "path": "/"
  }'
```

### Test the echo function

With the `echo` function registered and subscribed to HTTP events you can test the configuration by emitting HTTP events to the Event Gateway.

Submit an HTTP event to the Event Gateway:

```
curl -i --request POST \
  --url http://${EVENT_GATEWAY_IP}:4000/ \
  --data '{"message": "Hello world!"}'
```

The `echo` function will respond with the data submitted in the HTTP event:

```
HTTP/1.1 200 OK
Compute-Type: function
Date: Wed, 18 Jul 2018 14:41:36 GMT
Content-Length: 26
Content-Type: text/plain; charset=utf-8

{"message":"Hello world!"}
```

> Notice the value of the `Compute-Type` HTTP header. It was set to `function` by the `echo` function.

In addition, check the `echo` function logs in the portal Logs window. Output similar to the following is logged in executing the function:

```
2018-07-18T15:08:45.581 [Info] Function started (Id=8dea1402-8e84-4de1-8729-8e89fe92fb0c)
2018-07-18T15:08:45.581 [Info] JavaScript HTTP trigger function processed a request.
2018-07-18T15:08:45.581 [Info] Function completed (Success, Id=8dea1402-8e84-4de1-8729-8e89fe92fb0c, Duration=3ms)
```

## Routing Events to Kubernetes Services

In modern Serverless architectures events are typically routed to functions running on fully managed FaaS platforms such as [Azure Functions](https://azure.microsoft.com/en-us/services/functions/), [Google Cloud Functions](https://cloud.google.com/functions), or [AWS Lambda](https://aws.amazon.com/lambda). In some situations, such as low latency requirements, it maybe preferable to route events to existing applications running on traditional infrastructure.

In this section you will deploy the `echo` application using Kubernetes and configure the Event Gateway to route HTTP events to it.

Create the `echo` deployment and service:

```sh 
$ kubectl create -f deployments/echo.yaml

deployment "echo" created
service "echo" created
```

Verify the `echo` deployment is up and running:

```
$ kubectl get pods

NAME                             READY     STATUS    RESTARTS   AGE
echo-77d48cb484-728kq            1/1       Running   0          1m
etcd-0                           1/1       Running   0          2m
event-gateway-5ff8554766-jhs6v   1/1       Running   0          2m
event-gateway-5ff8554766-jpmwp   1/1       Running   0          2m
```

Register the `echo` service using an unique function ID:

```sh
curl --request POST \
  --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/functions \
  --header 'content-type: application/json' \
  --data '{
    "functionId": "echo-service",
    "type": "http",
    "provider":{
      "url": "http://echo.default.svc.cluster.local"
    }
  }'
```

> The provider URL follows the standard format for accessing cluster local services. In this case the `echo` deployment runs in the `default` namespace. This configuration works because the Event Gateway is running in the same cluster as the `echo` deployment.

At this point the `echo` service has been registered with the Event Gateway. 

In this section you will create an HTTP event subscription that binds the `echo-service` to HTTP events received on the `POST` method and the `/echosvc` path pair:

```sh
curl --request POST \
 --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/subscriptions \
 --header 'content-type: application/json' \
 --data '{
    "functionId": "echo-service",
    "event": "http",
    "method": "POST",
    "path": "/echosvc"
}'
```

> If you want to subscribe this new function to HTTP events on POST method and `/` path, you need to delete the current subscription for HTTP events on the `POST` method `/` path pair first, then create an HTTP event subscription for the echo-service function as there can only be one function subscribed to HTTP events for a given path and method pair.


Test the `echo` service by emitting an HTTP event to the Event Gateway:

```sh
curl -i --request POST \
  --url http://${EVENT_GATEWAY_IP}:4000/echosvc \
  --data '{"message": "Hello World!"}'
```

```
HTTP/1.1 200 OK
Compute-Type: container
Date: Wed, 18 Jul 2018 18:09:43 GMT
Content-Length: 27
Content-Type: text/plain; charset=utf-8

{"message": "Hello World!"}
```

> Notice the value of the `Compute-Type` HTTP header. It was set to `container` by the echo service.

Review the `echo` container logs:

```sh
$ kubectl logs echo-77d48cb484-728kq

2018/07/18 17:28:26 Starting HTTP server...
2018/07/18 18:08:22 Handling HTTP event 18efc24a-5735-41a8-8d39-45fa70f02b6b ...
```

## Clean Up

```sh
$ az group delete --name rg-eventgateway
```
> [note] This tutorial assumes that you create all resources in Azure under the resource group named `rg-eventgateway`. 


## LINKS
- [Event Gateway Project Github](https://github.com/serverless/event-gateway)
- [Event Gateway API References](https://github.com/serverless/event-gateway/blob/master/docs/api.md)
- [Serverless Event Gateway on Kubernetes](https://github.com/kelseyhightower/event-gateway-on-kubernetes)
- [Azure Kubernetes Service(AKS)](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- [Azure Functions](https://azure.microsoft.com/en-us/services/functions/)
- [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest)
- [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview)
