#!/bin/bash
set -x -e

EVENT_GATEWAY_IP=$(kubectl get svc event-gateway -o jsonpath={.status.loadBalancer.ingress[0].ip})
echo "EVENT_GATEWAY_IP=$EVENT_GATEWAY_IP"

curl -i --request POST \
  --url http://${EVENT_GATEWAY_IP}:4000/echosvc \
  --data '{"message": "Hello World!"}'
