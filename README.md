# Kustomization for Deploying Red Hat OpenShift Service Mesh

Red Hat OpenShift Service Mesh product documentation can be found [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.3/html/service_mesh/index).

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
