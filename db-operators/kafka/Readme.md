<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Kafka Kubernetes Operator](#Kafka-kubernetes-operator)
  - [Prerequisites](#prerequisites)
  - [Install the Operator](#install-the-operator)
  - [Start Kafka](#start-kafkadb)
    - [Resource requests and limits](#resource-requests-and-limits)
    - [Certificate signing](#certificate-signing)
    - [Apply the custom resource](#apply-the-custom-resource)
  - [Access the DB Console](#access-the-db-console)

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



