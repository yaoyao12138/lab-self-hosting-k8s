<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [CockroachDB Kubernetes Operator](#cockroachdb-kubernetes-operator)
  - [Prerequisites](#prerequisites)
  - [Install the Operator](#install-the-operator)
  - [Start CockroachDB](#start-cockroachdb)
    - [Resource requests and limits](#resource-requests-and-limits)
    - [Certificate signing](#certificate-signing)
    - [Apply the custom resource](#apply-the-custom-resource)
  - [Access the SQL shell](#access-the-sql-shell)
  - [Access the DB Console](#access-the-db-console)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# CockroachDB Kubernetes Operator

The CockroachDB Kubernetes Operator deploys CockroachDB on a Kubernetes cluster. You can use the Operator to manage the configuration of a running CockroachDB cluster. Please learn detail information from the repo: <https://github.com/cockroachdb/cockroach-operator>.

## Prerequisites

- Kubernetes 1.18 or higher
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Install the Operator

Apply the custom resource definition (CRD) for the Operator:

```
kubectl apply -f https://raw.githubusercontent.com/cockroachdb/cockroach-operator/master/install/crds.yaml
```

Apply the Operator manifest. By default, the Operator is configured to install in the `cockroachdb` namespace.

```
kubectl apply -f ./operator.yaml
```

> **Note:** The Operator can only install CockroachDB into its own namespace.

Validate that the Operator is running:

```
kubectl get pods
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
cockroach-operator-6f7b86ffc4-9ppkv   1/1     Running   0          54s
```

## Start CockroachDB

```
kubectl apply -f ./operator.yaml
```

> **Note:** The latest stable CockroachDB release `v21.1.7` is specified by default in `image.name`.

### Resource requests and limits

By default, the Operator allocates 2 CPUs and 8Gi memory to CockroachDB in the Kubernetes pods.

### Certificate signing

The Operator generates and approves 1 root and 1 node certificate for the cluster.

### Apply the custom resource

Apply `example.yaml`:

```
kubectl create -f ./example.yaml
```

Check that the pods were created:

```
kubectl get pods -n cockroachdb
```

```
NAME                                  READY   STATUS    RESTARTS   AGE
cockroach-operator-6f7b86ffc4-9t9zb   1/1     Running   0          3m22s
cockroachdb-0                         1/1     Running   0          2m31s
cockroachdb-1                         1/1     Running   0          102s
cockroachdb-2                         1/1     Running   0          46s
```

Each pod should have `READY` status soon after being created.

## Access the SQL shell

To use the CockroachDB SQL client, first launch a secure pod running the `cockroach` binary.

```
kubectl create -f ./client-secure-operator.yaml
```

Get a shell into the client pod:

```
kubectl exec -n cockroachdb -it cockroachdb-client-secure -- ./cockroach sql --certs-dir=/cockroach/cockroach-certs --host=cockroachdb-public
```

If you want to [access the DB Console](#access-the-db-console), create a SQL user with a password while you're here:

```
CREATE USER roach WITH PASSWORD 'Q7gc8rEdS';
```

Then assign `roach` to the `admin` role to enable access to [secure DB Console pages](https://www.cockroachlabs.com/docs/stable/ui-overview.html#db-console-security):

```
GRANT admin TO roach;
```

```
\q
```

## Access the DB Console

To access the cluster's [DB Console](https://www.cockroachlabs.com/docs/stable/ui-overview.html), port-forward from your local machine to the `cockroachdb-public` service:

```
kubectl port-forward service/cockroachdb-public 8080
```

Access the DB Console at `https://localhost:8080`.

