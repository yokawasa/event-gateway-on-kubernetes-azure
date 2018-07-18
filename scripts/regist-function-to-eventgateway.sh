#!/bin/bash
set -x -e

FUNCTION_URL="https://myazfunc001.azurewebsites.net/api/echo"

EVENT_GATEWAY_IP=$(kubectl get svc event-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "EVENT_GATEWAY_IP=$EVENT_GATEWAY_IP"

echo "Regist a function..."
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
## output log
# {"space":"default","functionId":"echo","type":"http","provider":{"url":"https://myazfunc001.azurewebsites.net/api/echo"}}

echo "Create a subscription..."
curl --request POST \
 --url http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/subscriptions \
 --header 'content-type: application/json' \
 --data '{
    "functionId": "echo",
    "event": "http",
    "method": "POST",
    "path": "/"
}'
## output log
# {"space":"default","subscriptionId":"http,POST,%2F","event":"http","functionId":"echo","method":"POST","path":"/"}

