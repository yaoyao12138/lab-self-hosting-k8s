# The Opinionated Sandbox for Self-hosted Instana on Kubernetes

This util helps you launch the self-hosted Instana for Kubernetes in a KIND cluster automatically which can be used for quick demo, PoC, or dev environment. Tested on Ubuntu.

## Overview

Typically, you need two Ubuntu VMs:

| Machine  | Resource
|:---------|:--------
| machine1 | 16 core, 32G memory, 250G disk
| machine2 | 16 core, 64G memory, 250G disk

* Use machine1 to install Instana databases and NFS service (for tracing spans persistence).
* Use machine2 to install KIND cluster and Instana workloads run on it.

![w](architecture.png)

## How to run?

Clone this Git repository to each of your above machines first, then run the `install.sh` to start the installation.

Before you install, make sure you define the following settings using environment variables:

```console
export INSTANA_DOWNLOAD_KEY="your download key"
export INSTANA_SALES_KEY="your sales key"
```

On the machine that runs KIND cluster and Instana workloads, please also define the hostname for the machine that runs Instana databases:

```console
export INSTANA_DB_HOST="the hostname for the machine that runs Instana databases, e.g. machine1"
export INSTANA_FQDN="the Fully Qualified Domain Names (FQDN) for all ingress into instana backend"
```

Please note here is the hostname, not the IP address. The util will auto-resolve the IP address for the specified hostname as needed.

You can also modify `./config.sh` for more settings customization.

### Bring up environment

Bring up Instana databases and NFS service on one machine:

```console
./install.sh up db
./install.sh up nfs
```

Bring up KIND and Instana workloads on another machine:

```console
./install.sh up k8
```

### Use local registry

You can use local registry to speed up the installation by caching all Instana images to a local registry.

Bring up a local registry on the machine that runs KIND and Instana workloads. This will pre-pull all images needed for Instana installation and cache them to the local registry:

```console
./install.sh up reg
```

To use the local registry, add `--reg` when bring up KIND and Instana workloads on that machine:

```console
./install.sh up k8 --reg
```

### Setup instana agent for selfmonitoring

To self monitor this box on the instana installation. Just roll out the instana agent with this command.
```console
./install.sh up agent
```

### Clean up

To take down Instana databases on your machine:

```console
./install.sh down db
```

To take down KIND and Instana workloads on your machine:

```console
./install.sh down k8
```

## How to access?

After Instana is launched, to access Instana UI, open https://${INSTANA_FQDN} in browser, username: admin@instana.local, password: passw0rd.

Here $INSTANA_FQDN is the hostname for the machine that runs KIND and Instana workloads.
