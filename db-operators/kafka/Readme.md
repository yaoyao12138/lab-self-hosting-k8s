<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Kafka Kubernetes Operator](#Kafka-kubernetes-operator)
  - [Prerequisites](#prerequisites)
  - [Install the Operator](#install-the-operator)
  - [Provision the Apache Kafka cluster](#provision-the-apache-kafka-cluster)
  - [Send and receive messages](#send-and-receive-messages)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Kafka Kubernetes Operator

Strimzi simplifies the process of running Apache Kafka in a Kubernetes cluster. You can use strimzi which provides Operators for managing a Kafka cluster running within a Kubernetes cluster.  
Please learn detail information from the repo: <https://github.com/strimzi/strimzi-kafka-operator>.

## Prerequisites

- Kubernetes 1.18 or higher
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Install the Operator

Create or choose a namespace for Operator installed:  
```
KAFKA_NS=kafka
kubectl create namespace $KAFKA_NS
```
Apply the Operator related resources like custom resource definition (CRD), clusterrolebinding and etc.

```
kubectl apply -f "https://strimzi.io/install/latest?namespace=$KAFKA_NS" -n $KAFKA_NS
```

Validate that the Operator is running:

```
kubectl get pods -n $KAFKA_NS
```

```
NAME                                     READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-85bb4c6-4gnjc   1/1     Running   0          38s
```

## Provision the Apache Kafka cluster

Build a persistent Apache Kafka Cluster with one node each for Apache Zookeeper and Apache Kafka:

```
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-persistent-single.yaml -n $KAFKA_NS
```
We now need to wait while Kubernetes starts the required pods, services and so on:
```
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n $KAFKA_NS

```
Validate that the Kafka cluster is running:

```
kubectl get pods -n $KAFKA_NS
```
```
NAME                                          READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-85bb4c6-4gnjc        1/1     Running   0          21m
my-cluster-zookeeper-0                        1/1     Running   0          106s
my-cluster-kafka-0                            1/1     Running   0          67s
my-cluster-entity-operator-6b495ccbc5-cjbws   3/3     Running   0          41s
```

## Send and receive messages

Run a simple producer to send messages to a Kafka topic (the topic will be automatically created):

```
kubectl -n $KAFKA_NS run kafka-producer -ti --image=quay.io/strimzi/kafka:0.26.0-kafka-3.0.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --broker-list my-cluster-kafka-bootstrap:9092 --topic my-topic
```
* Note: * If see this message, just ignore it and keep enter message like `test`
```
>[2021-11-22 07:56:54,900] WARN [Producer clientId=console-producer] Error while fetching metadata with correlation id 1 : {my-topic=LEADER_NOT_AVAILABLE} (org.apache.kafka.clients.NetworkClient)
>test
```

Receive them in a different terminal:

```
kubectl -n $KAFKA_NS run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.26.0-kafka-3.0.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
```
```
If you don't see a command prompt, try pressing enter.

test
```
You can check and receive the message `test`

