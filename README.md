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

Make sure that the csvs deployed successfully:

```
$ oc get csv --namespace openshift-operators
NAME                                         DISPLAY                          VERSION               REPLACES   PHASE
elasticsearch-operator.4.3.23-202005270305   Elasticsearch Operator           4.3.23-202005270305              Succeeded
jaeger-operator.v1.17.2                      Red Hat OpenShift Jaeger         1.17.2                           Succeeded
kiali-operator.v1.12.12                      Kiali Operator                   1.12.12                          Succeeded
servicemeshoperator.v1.1.2.2                 Red Hat OpenShift Service Mesh   1.1.2+2                          Succeeded
```

You should now see the operators running in the *openshift-operators* project:

```
$ oc get pod --namespace openshift-operators
NAME                                      READY   STATUS    RESTARTS   AGE
elasticsearch-operator-5646d8fd56-8qt6n   1/1     Running   0          13m
istio-node-49dwm                          2/2     Running   0          10m
istio-node-5cgxr                          2/2     Running   0          10m
istio-node-6688f                          2/2     Running   0          10m
istio-node-7qsgh                          2/2     Running   0          10m
istio-node-ddtkf                          2/2     Running   0          10m
istio-node-hl7mf                          2/2     Running   0          10m
istio-operator-5666475df8-b2648           1/1     Running   0          12m
jaeger-operator-b8fd89b48-5tdn5           1/1     Running   0          12m
kiali-operator-6459ff7f99-kjprc           2/2     Running   0          12m
```

## Deploying Service Mesh control plane

Install service mesh control plane:

```
$ oc apply --kustomize service-mesh-instance/overlays/development
```

Wait until the service mesh control plane deploys. Verify that the Kubernetes resources deployed successfully:

```
$ oc get --kustomize service-mesh-instance/overlays/development
NAME                     STATUS   AGE
namespace/istio-system   Active   2m23s

NAME                                               READY   STATUS              TEMPLATE   VERSION   AGE
servicemeshcontrolplane.maistra.io/control-plane   9/9     InstallSuccessful   default    v1.1      2m23s

NAME                                       READY   STATUS       AGE
servicemeshmemberroll.maistra.io/default   0/0     Configured   2m23s
```

## Discovering Service Mesh endpoints

Discover the hostnames of service mesh endpoints:

```
$ oc get route --namespace istio-system
```

## Deploying Bookinfo application

Follow the instructions in the chapter [Example Application ](https://docs.openshift.com/container-platform/4.3/service_mesh/service_mesh_day_two/ossm-example-bookinfo.html) to deploy the example [Bookinfo application](https://istio.io/docs/examples/bookinfo/).

```
$ oc new-project bookinfo
```

```
$ (cat <<EOF
apiVersion: maistra.io/v1
kind: ServiceMeshMember
metadata:
  name: default
  namespace: bookinfo
spec:
  controlPlaneRef:
    name: control-plane
    namespace: istio-system
EOF
) | oc apply --filename -
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

Obtain a hostname of the Istio ingress route that was created automatically by [Istio OpenShift Routing](https://docs.openshift.com/container-platform/4.4/service_mesh/service_mesh_day_two/ossm-auto-route.html):

```
$ oc get route \
    --namespace istio-system \
    --selector maistra.io/gateway-name=bookinfo-gateway,maistra.io/gateway-namespace=bookinfo \
    --output jsonpath='{.items[*].spec.host}'
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
) | oc apply --filename -
```

Obtain a hostname of the Istio ingress route that was created automatically by Istio OpenShift Routing:

```
$ oc get route \
    --namespace istio-system \
    --selector maistra.io/gateway-name=bookinfo-gateway,maistra.io/gateway-namespace=bookinfo \
    --output jsonpath='{.items[*].spec.host}'
```

Then visit `https://<route_hostname>/productpage` with your browser.

#### Creating a custom TLS route

In the previous section, the TLS route was created automatically by the Istio OpenShift Routing. You can choose to create your custom passthrough route to better control its parameters. For example:

```
$ oc create route passthrough \
    bookinfo \
    --namespace istio-system \
    --service istio-ingressgateway \
    --port https
    --hostname bookinfo
```

Obtain a hostname of the custom route:

```
$ oc get route --namespace istio-system bookinfo --output jsonpath='{.spec.host}'
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
