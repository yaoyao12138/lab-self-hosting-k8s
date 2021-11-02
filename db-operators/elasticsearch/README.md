<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Install elasticsearch operator as elasticsearch database source in Instana k8s Cluster](#install-elasticsearch-operator-as-elasticsearch-database-source-in-instana-k8s-cluster)
  - [ECK stack brief description](#eck-stack-brief-description)
  - [Install elasticsearch CRDs](#install-elasticsearch-crds)
  - [Install elasticsearch operator](#install-elasticsearch-operator)
  - [Create elasticsearch instance](#create-elasticsearch-instance)
  - [Get credential of elasticsearch instance for Instana accessing](#get-credential-of-elasticsearch-instance-for-instana-accessing)
  - [Get service of elasticsearch cluster](#get-service-of-elasticsearch-cluster)
  - [Apply elasticsearch operator in Instana k8s Cluster](#apply-elasticsearch-operator-in-instana-k8s-cluster)
    - [Known issue](#known-issue)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Install elasticsearch operator as elasticsearch database source in Instana k8s Cluster

This is a tutorial for how to install elasticsearch operator and configre it as elasticsearch database source in Instana Cluster, in which elasticsearch is used to store and query instana product search, event and snapshot data.



### ECK stack brief description

elasticsearch operator is a component of Elastic Cloud on Kubernetes (ECK) stack, which is the official operator by Elastic for automating the deployment, provisioning, management, and orchestration of Elasticsearch, Kibana, APM Server, Beats, Enterprise Search, Elastic Agent and Elastic Maps Server on Kubernetes.

Current features of ECK:
  - Elasticsearch, Kibana, APM Server, Enterprise Search, Beats, Elastic Agent and Elastic Maps Server deployments
  - TLS Certificates management
  - Safe Elasticsearch cluster configuration and topology changes
  - Persistent volumes usage
  - Custom node configuration and attributes
  - Secure settings keystore updates

Supported cloud versions:
  - Kubernetes 1.18-1.22
  - OpenShift 3.11, 4.4-4.8
  - Google Kubernetes Engine (GKE), Azure Kubernetes Service (AKS), and Amazon Elastic Kubernetes Service (EKS)



### Install elasticsearch CRDs 

This will create Custom Resource Definitions(CRD) used by Elasticsearch Operator,including Elasticsearch, Kibana, APM Server, Enterprise Search, Beats, Elastic Agent and Elastic Maps Server.
```console
$ kubectl apply -f crds.yaml
customresourcedefinition.apiextensions.k8s.io/agents.agent.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/apmservers.apm.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/beats.beat.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticmapsservers.maps.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/elasticsearches.elasticsearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/enterprisesearches.enterprisesearch.k8s.elastic.co created
customresourcedefinition.apiextensions.k8s.io/kibanas.kibana.k8s.elastic.co created
```



### Install elasticsearch operator 

This will create required resource used by Elasticsearch Operator, including namespace where elasticsearch resides and serviceaccount, secret, configmap and other stuff.
```console
$ kubectl apply -f operator.yaml
namespace/elastic-system created
serviceaccount/elastic-operator created
secret/elastic-webhook-server-cert created
configmap/elastic-operator created
clusterrole.rbac.authorization.k8s.io/elastic-operator created
clusterrole.rbac.authorization.k8s.io/elastic-operator-view created
clusterrole.rbac.authorization.k8s.io/elastic-operator-edit created
clusterrolebinding.rbac.authorization.k8s.io/elastic-operator created
service/elastic-webhook-server created
statefulset.apps/elastic-operator created
validatingwebhookconfiguration.admissionregistration.k8s.io/elastic-webhook.k8s.elastic.co created
```



### Create elasticsearch instance 

After above elasticsearch related definitions are created, at least one elasticsearch cluster instance must be created to support instana store and query data.  There is a `elasticsearch-instance.default.yaml`  with default value as sample yaml file  , you can change the values as you want or simple use the default yaml file to create elasticsearch cluster instance.

**sample elasticsearch cluster instance definition**
```yaml
$ cat elasticsearch-instance.default.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: onprem_onprem
spec:
  version: 7.15.1
  nodeSets:
  - name: default
    count: 3
    config:
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

Note:
- name of Elasticsearch: default is `onprem_onprem`
- version is `7.15.1`
- count : this is what many pods are included in elasticsearch cluster, and default number  is `3`
- storage: elasticsearch cluster uses Persistent volumesClaim( PVC) to store index and document data, :  the default PVC storage is `1Gi` meaning 1 Giga byts volume , you can change to your data vloume, such as `2Gi` or `5Gi`
- storageClassName:  in the sample defintion, the storageClass Name of PVC is omitted, meaning the **default** storageClass in the instana cluster is used. If not to use the default storageClass, you should define the storageClassName explicitly in the same level of `resources`.


Below is another sample with changed values: 
```yaml
$ cat my-elasticsearch-instance.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: myES 
spec:
  version: 7.10.2
  nodeSets:
  - name: default
    count: 5
    config:
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data # Do not change this name unless you set up a volume mount for the data path.
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 5Gi
        storageClassName: standard
```



### Get credential of elasticsearch instance for Instana accessing
To access elasticsearch cluster even from the cluster internal, elasticsearch user name and password are required. After elasticsearch instance is created, a set of user name and password are prepared, that the user name is always `elastic`, and the password can be got from secret `<es-instance-name>-es-elastic-user` in namespace `elastic-system`. For example. in my env, the elasticsearch instance name is `onprem_onprem`, then the password secret name is `onprem_onprem-es-elastic-user`

```sh
esname=onprem_onprem
espwdsecret=${esname}-es-elastic-user
export espassword=$(kubectl get secret $espwdsecret -o jsonpath='{.data.elastic}' -n elastic-system | base64 -d )
export esusername=elastic
echo $espassword
```



###  Get service of elasticsearch cluster

After a elasticsearch instance is created, a elasticsearch service is prepared to access it via defaul `9200` port. 
```sh
esname=onprem_onprem
export svcname=$( kubectl get svc -n elastic-system | grep "${esname}-es-http" | awk '{ print $1 }')
echo $svcname
```

Then in cluster internal, elasticsearch can be accessed via its user namek, password and service like below : 
```console
$ curl -ks -u "$esusername:$espassword" "https://$svcname.elastic-system:9200"
{
  "name" : "onprem_onprem-es-default-1",
  "cluster_name" : "onprem_onprem",
  "cluster_uuid" : "DQG31VfwS2mNnOUBn2YxmA",
  "version" : {
    "number" : "7.15.1",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "83c34f456ae29d60e94d886e455e6a3409bba9ed",
    "build_date" : "2021-10-07T21:56:19.031608185Z",
    "build_snapshot" : false,
    "lucene_version" : "8.9.0",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}

```



**Now the elasticsearch is ready to be connected by instana.**



### Apply elasticsearch operator in Instana k8s Cluster

Per instana doc, for [Deploying the Database Layer](https://www.instana.com/docs/release-209/self_hosted_instana_k8s/installation/#deploying-the-database-layer)

There are several ways to provision the database layer:

- Setup a new [single host database layer](https://www.instana.com/docs/release-209/self_hosted_instana_k8s/single_host_database)
- Setup a set of clusters for the different databases based on our [distkit](https://github.com/instana/onprem-distkit)

- Role your own installation (dedicated operators, hosted solutions, ...)

  

The elasticsearch operator preparation above is for the 3rd method. 

To apply the dedicated elasticsearch operators, instana setting must be changed according to elasticsearch instance and then applied to take into effect:

Go to the `settings.hcl` direcoty and change the databases `elasticsearch` segment to below in `settings.hcl`  : 

```yaml
databases "<elasticsearch-instance-name>-es-http" = {
    database       = "elasticsearch"
    namespace      = "elastic-system"
    create_service = false
}
```

in my env, the elasticsearch instance name is `instana`, so it will look like:

```yaml
databases "onprem_onprem-es-http" = {
    database       = "elasticsearch"
    namespace      = "elastic-system"
    create_service = false
}
```



And then to apply the elasticsearch setting change by instana command:

```sh
kubectl instana apply
```



#### Known issue

In instana **`209`** version, since there is **no username and password placeholder** in `databases` settings for elasticsearch ( and other db operator, eg. Cassandra), the elasticsearch operator based DB will NOT work until the username/password are accepted by instana core.
