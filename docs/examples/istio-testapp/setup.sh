#!/bin/bash

ROUTER_DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}')

echo Setting ROUTER_DOMAIN=$ROUTER_DOMAIN

sed \
  --in-place \
  --expression "s/@@ROUTER_DOMAIN@@/$ROUTER_DOMAIN/g" \
  *.yaml
