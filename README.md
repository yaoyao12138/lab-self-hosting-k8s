<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Instana Self-hosted On Kubernetes Installation Guide](#instana-self-hosted-on-kubernetes-installation-guide)
  - [Install Manually](#install-manually)
  - [Install Automatically](#install-automatically)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Instana Self-hosted On Kubernetes Installation Guide

The Instana self-hosted installation on Kubernetes consists of a database backend, kubectl plugin, a Kuberenetes operator, and number of components and services, each one running as an individual container running in the Kubernetes cluster after deployment.

There are some official document at [here](https://www.instana.com/docs/self_hosted_instana_k8s) to enable end user install self-hosted Instana on Kubernetes manually step by step. But it depend on an existing Kubernetes Cluster and also need user manually create some `LoadBalancer` services in order to access the Instana UI. This is actually a bit complex for some users who is not familiar with Kubernetes or customers who are not able to create `LoadBalancer` services.

This repo is mainly providing some simple ways to enable end user can bring up self-hosted Instana on Kubernetes quickly. The end user can either install manually or using some automaition tools here to install automatically.

## Install Manually

In the [manual-install](./manual-install) folder, there is a [README.md](./manual-install/README.md) file to guide the end user to install Instana on Kubernetes manually.

## Install Automatically

In the [automatic-install](./automatic-install) folder, there is a [README.md](./automatic-install/README.md) file to guide the end user to install Instana on Kubernetes automatically with a script.

We are now working with another automation method to install Instana on Kubernetes via [Crossplane](https://crossplane.io/), it will be available soon.
