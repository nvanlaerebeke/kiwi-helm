# kiwi-helm

Helm chart for `Kiwi TCMS`

## Packaging

To create the helm package:

```console
make package
```

## Publishing to an OCI registry

Can be published to any `OCI` registry, pass the `REGISTRY=` when running `make push` to override the default docker hub registry (see `Makefile` for more details).

First log in with helm:

```console
helm registry login registry-1.docker.io -u <username>
```

To create and push the package to an `OCI` registry:

```console
make push
```

## Using the Chart

The chart deploys `Kiwi TCMS` with `Postgres` (default).  

A minimal deployment would look like:

```console
helm upgrade --install kiwitcms registry-1.docker.io/crazytje/kiwitcms:<version>
```

This will install `kiwitcms` without persistence and will only be reachable within the cluster (ClusterIP).  
Add port forwarding to make it accessable for this test case:

```console
kubectl port-forward <pod> 30000:8080
```

Go to `http://localhost:30000` to verify the deployment worked.  
This will be with a self-signed certificate for testing purposes.  
Note that the port forward is done on the `http` port, this is to verify the `http` to `https` redirect works.

## Persistence with existingVolumeClaim

Persistence can be done using the storage class or using an existing volume claim.

Example yaml for storing with local path is shown below:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kiwi-db
  labels:
    app: kiwi-db
spec:
  storageClassName: standard
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "/data/kiwi-db"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kiwi-db-claim
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  selector:
    matchLabels:
      app: kiwi-db
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kiwi-storage
  labels:
    app: kiwi-storage
spec:
  storageClassName: standard
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "/data/kiwi-storage"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kiwi-storage-claim
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  selector:
    matchLabels:
      app: kiwi-storage
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
```

Deployment would now be:

```console
helm upgrade --install kiwitcms \
    --set persistence.enabled=true \
    --set persistence.existingClaim=kiwi-storage-claim \
    --set postgresql.primary.persistence.enabled=true \
    --set postgresql.primary.persistence.existingClaim=kiwi-db-claim \
    registry-1.docker.io/crazytje/kiwitcms:<version>
```

Note: be careful not to re-use an old postgres data folder, the passwords would not match and installation would fail.  

## Persistence Using Storage Class

This uses the storage classes that are configured in the cluster (example uses k3s's local-path):

```console
helm upgrade --install kiwitcms \
    --set persistence.enabled=true \
    --set postgresql.primary.persistence.enabled=true \
    --set postgresql.primary.persistence.create=true \
    --set persistence.storage.class=local-path \
    registry-1.docker.io/crazytje/kiwitcms:<version>
```

## Database Credentials

Both an internal and external database can be used.  
If an external database is used set `postgresql.enabled` to `false` and modify the `database.*` settings to reflect the external database.

### Custom password

When using an internal database a database password will be generated for you in the `kiwi-postgres-password` secret.  
A custom password can also be provided by setting the `postgresql.auth.existingSecret`.  
Make sure to disable `postgres.auth.create` when doing so.  

An example secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kiwi-postgres-password
data:
  postgres-password: cGFzc3dvcmQ=
  password: cGFzc3dvcmQ=
type: Opaque
```

This would set the `postgres` password for the `kiwi` and `postgres` user to `password`.

## Ingress

To use the ingress controller with `tls` that is provided with an existing secret deploy the helm chart as follows:

```console
helm upgrade --install kiwitcms \
    --set ingress.enabled=true \
    --set ingress.host=kiwitcms.example.com \
    --set ingress.secretName=secret-tls \
    registry-1.docker.io/crazytje/kiwitcms:<version>
```

## TLS

When using an ingress controller (`ingress.enabled`), provide the `TLS` secret in `ingress.secretName`.  

When not using the ingress controller a TLS certificate must be provided in `service.secretName`, if not your browser will just always show you the invalid certificate (self signed) that's installed by default.

This is fine for testing, not when running in production.  

Set `service.secretName` to the secret containing the `tls.crt` and `tls.key` keys, same as any other `kubernetes.io/tls` secret in kubernetes.

Example:

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: secret-tls
data:
  tls.crt: ...
  tls.key: ...
```

The `kiwi` container will now use that certificate for `TLS`.

An example deployment:

```console
helm upgrade --install kiwitcms \
    --set service.secretName=tls-secret \
    registry-1.docker.io/crazytje/kiwitcms:<version>
```

To access it, add the port-forwarding as this is a ClusterIP service by default:

```console
kubectl port-forward <pod> 443:8443
```

### NodePort

The above example doesn't expose the service if you're not using an ingress controller.  
This example exposes the services using NodePort.  

```console
helm upgrade --install kiwitcms \
    --set service.secretName=secret-tls \
    --set service.type=NodePort \
    --set service.port.http=30010 \
    --set service.port.https=30011 \
    registry-1.docker.io/crazytje/kiwitcms:<version>
```

```console
kubectl port-forward <pod> 443:8443
```

## Custom Nginx configuration

A custom `nginx` config is mounted when `ingress` is enabled.  
This is due to issues I was having getting the `ingress` to work with a `https` backend.  
It had to work with both `nginx` and `traefik` ingress controllers and it didn't so this was the quick fix for it.  

Any pull requests to fix this are welcome!

## Umbrella helm chart example

A quick example on how to create an umbrella chart using this chart:

The Chart.yaml:

```yaml
apiVersion: v1
name: kiwi
version: 0.0.1
appVersion: 0.0.1
description: Kiwi TCMS
dependencies:
  - name: kiwitcms
    version: "0.0.1"
    repository: "oci://registry-1.docker.io/crazytje"
```

The values yaml:

```yaml
kiwitcms:
  ingress:
    enabled: true
    host: kiwi.example.com
    secretName: secret-tls
  persistence:
    enabled: true
    existingClaim: kiwi-storage-claim
  postgres:
    auth:
      create: false
      existingSecret: kiwi-postgres-password
    primary:
      persistence:
        enabled: true
        existingClaim: kiwi-db-storage
```

the `./templates/*.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kiwi-db
  labels:
    app: kiwi-db
spec:
  storageClassName: standard
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "/data/kiwi/db"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kiwi-db-claim
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  selector:
    matchLabels:
      app: kiwi-db
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: kiwi-storage
  labels:
    app: kiwi-storage
spec:
  storageClassName: standard
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "/data/kiwi/uploads"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kiwi-storage-claim
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  selector:
    matchLabels:
      app: kiwi-storage
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
---
apiVersion: v1
kind: Secret
metadata:
  name: kiwi-postgres-password
data:
  postgres-password: cGFzc3dvcmQ=
  password: cGFzc3dvcmQ=
type: Opaque
```