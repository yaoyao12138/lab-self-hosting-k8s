**Table of Contents**
- [Install Strimizi Kafka Operator with Instana](#Install-Strimizi-Kafka-operator-with-instana)
  - [Prerequisites](#prerequisites)
  - [Overview](#overview)
  - [Install Strimizi Kafka Operator](iInstall-strimizi-kafka-operator)
  - [Create Kafka cluster](#create-kafka-cluster)
    - [Create a Kafka cluster with 1 ZooKeeper and 1 Kafka broker](#create-a-kafka-cluster-with-1-zooKeeper-and-1-kafka-broker)
    - [Create a Kafka cluster with 3 ZooKeepers and 3 Kafka brokers](#create-a-kafka-cluster-with-3-zooKeepers-and-3-kafka-brokers)
  - [Install Instana with Kafka](#install-instana-with-kafka)

# Install Strimizi Kafka Operator with Instana

This configuration uses the following version: 
- Instana version: 211
- Strimizi version: 0.24.0
- Kafka version: 2.7.1 
 
## Prerequisites

- Kubernetes cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Overview

The Kafka Operator could be deployed through Strimizi on a Kubernetes cluster. You can use the Strimizi Operator to manage the configuration of a running Kafka cluster.   
Please learn detail information from the repo: <https://github.com/strimzi/strimzi-kafka-operator>.


## Install Strimizi Kafka Operator

Download [manifest folder](https://github.com/yaoyao12138/lab-self-hosting-k8s/tree/db-operators/db-operators/kafka/manifest) 

Create a new kafka namespace such as `kafka` for the Strimzi Kafka Cluster Operator.  
```
kubectl create ns kafka
```

Deploy the CRDs and role-based access control (RBAC) resources for the Operator:

```
kubectl apply -f manifest/cluster-operator/ -n kafka
```

Validate that the Operator is running:

```
kubectl get pods

NAME                                         READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-788987dc55-f7tcz    1/1     Running   0          69s
```

## Create Kafka cluster
The number of ZooKeeper and Kafka broker depends on the Kubernetes cluster and scenario.

### Create a Kafka cluster with 1 ZooKeeper and 1 Kafka broker
```
kubectl apply -f manifest/kakfa-cluster-single.yaml -n kafka
```

Wait for the cluster to be deployed:
```
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n my-kafka-project
```
Check that the pods were created:

```
kubectl get pods -n kafka

NAME                                         READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-788987dc55-gtt8z    1/1     Running   0          34h
my-cluster-zookeeper-0                       1/1     Running   0          34h
my-cluster-kafka-0                           1/1     Running   0          34h
my-cluster-entity-operator-b74545ccb-6lgnk   3/3     Running   0          34h
```

### Create a Kafka cluster with 3 ZooKeepers and 3 Kafka brokers
```
kubectl apply -f manifest/kakfa-cluster-multiplied.yaml -n kafka
```

Wait for the cluster to be deployed:
```
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n my-kafka-project

```

Check that the pods were created:

```
kubectl get pods -n kafka
```

```
NAME                                         READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-788987dc55-f7tcz    1/1     Running   0          169m
my-cluster-zookeeper-0                       1/1     Running   0          167m
my-cluster-zookeeper-1                       1/1     Running   0          167m
my-cluster-zookeeper-2                       1/1     Running   0          167m
my-cluster-kafka-0                           1/1     Running   0          166m
my-cluster-kafka-1                           1/1     Running   0          166m
my-cluster-kafka-2                           1/1     Running   0          166m
my-cluster-entity-operator-b74545ccb-5mjsq   3/3     Running   2          166m
```

## Install Instana with Kafka 

Follow the step: [Installing an Operator-based Instana Setup](https://www.instana.com/docs/release-211/self_hosted_instana_k8s/installation/)   
And replace follow the kafka addresses `Datastores` [here](https://www.instana.com/docs/release-211/self_hosted_instana_k8s/installation/#325-datastores): 
```
spec:
  datastoreConfigs:
    - type: kafka
      addresses:
        - my-cluster-kafka-bootstrap.kafka
```

Then do what you need with Instana.

