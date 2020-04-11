# Kustomization for Deploying Red Hat OpenShift Service Mesh

Red Hat OpenShift Service Mesh product documentation can be found [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.3/html/service_mesh/index). This kustomization is based on the examples included in the product documentation.

You can refer to the [Maistra Istio Operator](https://github.com/Maistra/istio-operator) project on GitHub for further documentation on the operator.

## Deploying required operators

```
$ oc apply --kustomize elasticsearch-operator/base
```

```
$ oc apply --kustomize jaeger-operator/base
```

```
$ oc apply --kustomize kiali-operator/base
```

```
$ oc apply --kustomize service-mesh-operator/base
```

You should now see operators running in the *openshift-operators* project:

```
$ oc get pod --namespace openshift-operators
NAME                                     READY   STATUS    RESTARTS   AGE
elasticsearch-operator-6b4686b59-fz6cx   1/1     Running   0          11h
istio-operator-5f945bd597-z89qp          1/1     Running   0          11h
jaeger-operator-54b947db5d-lck5w         1/1     Running   0          11h
kiali-operator-6559fdc5bc-vspjd          1/1     Running   0          11h
```

## Deploying Service Mesh control plane

Install service mesh control plane:

```
$ oc apply --kustomize service-mesh-instance/overlays/development
```

Wait until the service mesh control plane deploys. Discover the service mesh endpoint hostnames:
```
$ oc get route --namespace istio-system
```

## Deploying Bookinfo application

Follow the instructions in the chapter [Example Application ](https://docs.openshift.com/container-platform/4.3/service_mesh/service_mesh_day_two/ossm-example-bookinfo.html) to deploy the example [Bookinfo application](https://istio.io/docs/examples/bookinfo/).

```
$ oc new-project bookinfo
```

```
$ oc patch \
    smmr default \
    --namespace istio-system \
    --type json \
    --patch '[{"op": "add", "path": "/spec/members", "value": []}]'
```

```
$ oc patch \
    smmr default \
    --namespace istio-system \
    --type json \
    --patch '[{"op": "add", "path": "/spec/members/-", "value": "bookinfo"}]'
```

```
$ oc apply \
    --namespace bookinfo \
    --filename https://raw.githubusercontent.com/Maistra/bookinfo/maistra-1.0/bookinfo.yaml
```

```
$ oc apply \
    --namespace bookinfo \
    --filename https://raw.githubusercontent.com/Maistra/bookinfo/maistra-1.0/bookinfo-gateway.yaml
```

```
$ oc apply --namespace bookinfo \
    --filename https://raw.githubusercontent.com/istio/istio/release-1.1/samples/bookinfo/networking/destination-rule-all-mtls.yaml
```

### Verifying the Bookinfo installation

Obtain a hostname of the Istio ingress route:

```
$ oc get route --namespace istio-system istio-ingressgateway --output jsonpath='{.spec.host}'
```

Then visit `http://<route_hostname>/productpage` with your browser.

Obtain the Kiali endpoint hostname:

```
$ oc get route --namespace istio-system kiali --output jsonpath='{.spec.host}'
```

Obtain the Jaeger endpoint hostname:

```
$ oc get route --namespace istio-system jaeger --output jsonpath='{.spec.host}'
```

### Creating a TLS route for the Bookinfo application

The following steps are based on [this article](https://access.redhat.com/solutions/4818911).

Create a secret `istio-ingressgateway-certs` that holds the certificate and private key for the TLS route. You can use a certificate specific for the route's hostname or reuse the wildcard certificate:

```
$ oc create secret tls \
    istio-ingressgateway-certs \
    --namespace istio-system \
    --cert wildcard.apps.mycluster.example.com.crt \
    --key wildcard.apps.mycluster.example.com.key
```

Remove the original plain-HTTP bookinfo gateway:

```
$ oc delete gateway bookinfo-gateway --namespace bookinfo
```

Create an HTTPS gateway instead:

```
$ (cat <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
  namespace: bookinfo
spec:
  selector:
    istio: ingressgateway
  servers:
  - hosts:
    - '*'
    port:
      name: https
      number: 443
      protocol: HTTPS
    tls:
      mode: SIMPLE
      privateKey: /etc/istio/ingressgateway-certs/tls.key
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
EOF
) | oc create --filename -
```
Create a passthrough route which sends the traffic to the Istio ingress gateway:

```
$ oc create route passthrough \
    istio-ingressgateway-tls \
    --namespace istio-system \
    --service istio-ingressgateway \
    --port https
```

Obtain a hostname of the Istio ingress route:

```
$ oc get route --namespace istio-system istio-ingressgateway-tls --output jsonpath='{.spec.host}'
```

Then visit `https://<route_hostname>/productpage` with your browser.

## Troubleshooting

Collect debugging data about the currently running Openshift cluster:

```
$ oc adm must-gather
```

Collect debugging information specific to OpenShift Service Mesh:

```
$ oc adm must-gather --image registry.redhat.io/openshift-service-mesh/istio-must-gather-rhel7:latest
```
