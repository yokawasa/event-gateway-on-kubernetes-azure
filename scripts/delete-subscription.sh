#!/bin/bash

EVENT_GATEWAY_IP=$(kubectl get svc event-gateway -o jsonpath={.status.loadBalancer.ingress[0].ip})
echo "EVENT_GATEWAY_IP=$EVENT_GATEWAY_IP"

curl -X DELETE \
  http://${EVENT_GATEWAY_IP}:4001/v1/spaces/default/subscriptions/http,POST,%2F
