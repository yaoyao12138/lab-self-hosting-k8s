<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Kafka Operator with Instana](#Kafka-operator-with-instana)
  - [Prerequisites](#prerequisites)
  - [Install the Operator](#install-the-operator)
  - [Start CockroachDB](#start-cockroachdb)
    - [Resource requests and limits](#resource-requests-and-limits)
    - [Certificate signing](#certificate-signing)
    - [Apply the custom resource](#apply-the-custom-resource)
  - [Access the SQL shell](#access-the-sql-shell)
  - [Access the DB Console](#access-the-db-console)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Kafka Operator with Instana
 
The Kafka Operator could be deployed through Strimizi on a Kubernetes cluster. You can use the Strimizi Operator to manage the configuration of a running Kafka cluster. Please learn detail information from the repo: <https://github.com/strimzi/strimzi-kafka-operator>.

## Prerequisites

- Kubernetes cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Corresponding version of strimizi](https://strimzi.io/downloads/) for the Kafka version of Instana. 

## Install the Operator

As follows, we will use the example of strimizi 0.24.0 which included Kafka 2.7.1 for Instana 211-1.  
For other version of Instana, pls replace the corresponding version of strimizi and Kafka.  

Download and Unzip the `strimzi-0.24.0.zip file` from [Strimizi Releases](https://github.com/strimzi/strimzi-kafka-operator/releases).  
```
wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.24.0/strimzi-0.24.0.zip 
unzip strimzi-0.24.0.zip
```

Create a new kafka namespace such as `kafka` for the Strimzi Kafka Cluster Operator.  
```
kubectl create ns kafka
```
Modify the installation files to reference the `kafka` namespace where you will install the Strimzi Kafka Cluster Operator.  
*Note: cd to `strimzi-0.24.0.zip` unzip folder* 
```
sed -i 's/namespace: .*/namespace: kafka/' install/cluster-operator/*RoleBinding*.yaml
```
Edit the install/cluster-operator/060-Deployment-strimzi-cluster-operator.yaml file and set the `STRIMZI_NAMESPACE` environment variable to the namespace `kafka`.
```
# ...
env:
- name: STRIMZI_NAMESPACE
  value: kafka
# ...
```
Deploy the CRDs and role-based access control (RBAC) resources for the Operator:

```
kubectl apply -f install/cluster-operator/ -n kafka
```

Validate that the Operator is running:

```
kubectl get pods
```

```
NAME                                         READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-788987dc55-f7tcz    1/1     Running   0          69s

```

## Create Kafka cluster with ZooKeeper and Kafka broker
The number of ZooKeeper and Kafka broker depends on the Kubernetes cluster and scenario.

### Create a new my-cluster Kafka cluster with 1 ZooKeeper and 1 Kafka broker.
```
cat << EOF | kubectl create -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 2.7.1
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
      - name: external
        port: 9094
        type: nodeport
        tls: false
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 100Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
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
strimzi-cluster-operator-788987dc55-gtt8z    1/1     Running   0          34h
my-cluster-zookeeper-0                       1/1     Running   0          34h
my-cluster-kafka-0                           1/1     Running   0          34h
my-cluster-entity-operator-b74545ccb-6lgnk   3/3     Running   0          34h
```

### Create a new my-cluster Kafka cluster with 3 ZooKeeper and 3 Kafka brokers.
```
cat << EOF | kubectl create -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 2.7.1
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
      - name: external
        port: 9094
        type: nodeport
        tls: false
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        deleteClaim: false
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 3
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 100Gi
      deleteClaim: false
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
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

## Sending and receiving messages

Create a topic to publish and subscribe from your external client.
```
cat << EOF | kubectl create -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  labels:
    strimzi.io/cluster: "my-cluster"
spec:
  partitions: 3
  replicas: 1
EOF
```

Get IP address and port: 
```
kubectl get service my-cluster-kafka-external-bootstrap -n kafka -o=jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```
```
kubectl get nodes --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

```

Download the latest Kafka binaries and install Kafka 2.7.1 on your local machine: [Apache Kafka download](http://kafka.apache.org/downloads)
```
wget https://archive.apache.org/dist/kafka/2.7.1/kafka_2.12-2.7.1.tgz
tar zxvf kafka_2.12-2.7.1.tgz
```
*Note: cd to `kafka_2.12-2.7.1.tgz` unzip folder* 

Open a terminal, start the Kafka console producer with the topic my-topic then type some message:
```
bin/kafka-console-producer.sh --broker-list <node-address>:_<node-port>_ --topic my-topic

```
Open a new terminal tab or window, and start the consumer to receive the messages:
```
bin/kafka-console-consumer.sh --bootstrap-server <node-address>:_<node-port>_ --topic my-topic --from-beginning

```
Verify that you see the incoming messages in the consumer console.

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

Then install agent through Instana UI to verify Instana installed successfully.

