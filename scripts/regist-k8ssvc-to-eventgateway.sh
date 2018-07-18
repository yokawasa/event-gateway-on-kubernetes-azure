#!/bin/bash
set -x -e

EVENT_GATEWAY_IP=$(kubectl get svc event-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "EVENT_GATEWAY_IP=$EVENT_GATEWAY_IP"

echo "Regist a function..."

# The provider URL follows the standard format for accessing cluster local services.
# In this case the echo deployment runs in the default namespace.
# This configuration works because the Event Gateway is running in the same cluster as the echo deployment.
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
## output log
# {"space":"default","functionId":"echo-service","type":"http","provider":{"url":"http://echo.default.svc.cluster.local"}}


# You subscribe this new function to HTTP events on POST method and /echosvc path, 
# create an HTTP event subscription for the echo-service function:
echo "Create a subscription..."
curl --request POST \
 --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/subscriptions \
 --header 'content-type: application/json' \
 --data '{
    "functionId": "echo-service",
    "event": "http",
    "method": "POST",
    "path": "/echosvc"
}'
# output log
# {"space":"default","subscriptionId":"http,POST,%2Fechosvc","event":"http","functionId":"echo-service","method":"POST","path":"/echosvc"}

