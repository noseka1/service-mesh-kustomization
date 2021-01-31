#!/bin/bash

set -euo pipefail

cd ./istio-system

if [ ! -f testapp-tls.key ]; then
  openssl req -newkey rsa:2048 -nodes -keyout testapp-tls.key -x509 -out testapp-tls.crt -subj '/CN=example.com'
fi
kustomize build . | oc apply --filename -

cd ../istio-testapp

ROUTER_DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}')

echo Setting ROUTER_DOMAIN=$ROUTER_DOMAIN

sed \
  --in-place \
  --expression "s/@@ROUTER_DOMAIN@@/$ROUTER_DOMAIN/g" \
  *.yaml

kustomize build . | oc apply --filename -

cd ..

CURL="curl --fail --retry 10 --retry-delay 5"
TEST_URL=testapp-http.$ROUTER_DOMAIN/status/200
echo Testing $TEST_URL ...
$CURL $TEST_URL
echo OK

TEST_URL=https://testapp-tls-edge.$ROUTER_DOMAIN/status/200
echo Testing $TEST_URL ...
$CURL -k $TEST_URL
echo OK
