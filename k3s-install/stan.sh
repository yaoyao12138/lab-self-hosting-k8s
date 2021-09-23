#!/bin/bash

####################
# Settings
####################

# OS and arch settings
HOSTOS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOSTARCH=$(uname -m)
SAFEHOSTARCH=${HOSTARCH}
if [[ ${HOSTOS} == darwin ]]; then
  SAFEHOSTARCH=amd64
fi
if [[ ${HOSTARCH} == x86_64 ]]; then
  SAFEHOSTARCH=amd64
fi
HOST_PLATFORM=${HOSTOS}_${HOSTARCH}
SAFEHOSTPLATFORM=${HOSTOS}-${SAFEHOSTARCH}

# Directory settings
ROOT_DIR=$(cd -P $(dirname $0) >/dev/null 2>&1 && pwd)
WORK_DIR=${ROOT_DIR}/.work
DEPLOY_LOCAL_WORKDIR=${WORK_DIR}/local/localdev
CACHE_DIR=${ROOT_DIR}/.cache
TOOLS_DIR=${CACHE_DIR}/tools
TOOLS_HOST_DIR=${TOOLS_DIR}/${HOST_PLATFORM}

mkdir -p ${DEPLOY_LOCAL_WORKDIR}
mkdir -p ${TOOLS_HOST_DIR}

# Custom settings
. ${ROOT_DIR}/config.sh

####################
# Utility functions
####################

CYAN="\033[0;36m"
NORMAL="\033[0m"
RED="\033[0;31m"

function info {
  echo -e "${CYAN}INFO  ${NORMAL}$@" >&2
}

function error {
  echo -e "${RED}ERROR ${NORMAL}$@" >&2
}

function wait-ns {
  local ns=$1
  echo -n "Waiting for namespace $ns ready "
  retries=100
  until [[ $retries == 0 ]]; do
    echo -n "."
    local result=$(kubectl get ns $ns -o name 2>/dev/null)
    if [[ $result == "namespace/$ns" ]]; then
      echo " Done"
      break
    fi
    sleep 1
    retries=$((retries - 1))
  done
  [[ $retries == 0 ]] && echo
}

function wait-ns-empty {
  local ns=$1
  echo -n "Waiting for namespace $ns becomes empty "
  retries=100
  until [[ $retries == 0 ]]; do
    echo -n "."
    local result=$(kubectl get pod -n $ns 2>/dev/null | wc -l)
    # echo $result
    if [[ $result == "0" ]]; then
      echo " Done"
      break
    fi
    sleep 1
    retries=$((retries - 1))
  done
  [[ $retries == 0 ]] && echo
}

function wait-deployment {
  local object=$1
  local ns=$2
  echo -n "Waiting for deployment $object in $ns namespace ready "
  retries=600
  until [[ $retries == 0 ]]; do
    echo -n "."
    local result=$(kubectl get deploy $object -n $ns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [[ $result == 1 ]]; then
      echo " Done"
      break
    fi
    sleep 1
    retries=$((retries - 1))
  done
  [[ $retries == 0 ]] && echo
}

function add-apt-source {
  local source_list="$1"
  local source_item="$2"
  local apt_key="$3"
  local grep_text="${source_item/[/\\[}"
  grep_text="${grep_text/]/\\]}"
  touch /etc/apt/sources.list.d/${source_list}
  if ! cat /etc/apt/sources.list.d/${source_list} | grep -q "${grep_text}"; then
    echo "${source_item}" >> /etc/apt/sources.list.d/${source_list}
    wget -qO - ${apt_key} | apt-key add -
  fi
}

function install-apt-package {
  local required_pkg="$1"
  local pkg_version="$2"
  local arg="${required_pkg}"
  if [[ -n ${pkg_version} ]]; then
    arg="${required_pkg}=${pkg_version}"
  fi

  local pkg_ok=$(dpkg-query -W --showformat='${Status} [${Version}]\n' ${required_pkg} | grep "install ok installed")
  if [[ -z ${pkg_ok} ]]; then
    # apt-get update
    apt-get --yes install ${arg}
  else
    if [[ -n ${pkg_version} ]]; then
      if [[ ! ${pkg_ok} =~ "[${pkg_version}]" ]]; then
        error "${required_pkg} detected but version mismatch, please uninstall the exiting version first."
        exit 1
      fi
    else
      echo "${required_pkg} detected."
    fi
  fi
}

function install-helm-release {
  local helm_repository_name=$1;  shift
  local helm_repository_url=$1;   shift
  local helm_release_name=$1;     shift
  local helm_release_namespace=$1;shift
  local helm_chart_name=$1;       shift
  local helm_chart_ref="${helm_repository_name}/${helm_chart_name}"

  # Update helm repo
  if ! "${HELM}" repo list -o yaml | grep -i "Name:\s*${helm_repository_name}\s*$" >/dev/null; then
    ${HELM} repo add "${helm_repository_name}" "${helm_repository_url}"
  fi
  ${HELM} repo update

  # Create namespace if not exists
  kubectl get ns "${helm_release_namespace}" >/dev/null 2>&1 || \
    kubectl create ns "${helm_release_namespace}"

  # Install helm release
  ${HELM} upgrade --install "${helm_release_name}" --namespace "${helm_release_namespace}" --kubeconfig "${KUBECONFIG}" \
    "${helm_chart_ref}" $@ 2>/dev/null

  wait-deployment ${helm_chart_name} ${helm_release_namespace}
}

####################
# Preflight check
####################

function preflight-check-key {
  if [[ -z $INSTANA_DOWNLOAD_KEY ]]; then
    error "INSTANA_DOWNLOAD_KEY must not be empty, exit."
    exit 1
  fi

  if [[ -z $INSTANA_SALES_KEY ]]; then
    error "INSTANA_SALES_KEY must not be empty, exit."
    exit 1
  fi
}

function preflight-check-db {
  if ! command -v instana >/dev/null 2>&1; then
    if [[ -z $INSTANA_DB_HOST ]]; then
      error "INSTANA_DB_HOST must not be empty, exit."
      exit 1
    fi
  else
    INSTANA_DB_HOST=$(hostname)
  fi
}

####################
# Install docker
####################

function install-docker {
  if ! command -v docker >/dev/null 2>&1; then
    info "Installing docker ..."

    curl https://releases.rancher.com/install-docker/19.03.sh | sh

    info "Installing docker ... OK"
  fi
}

####################
# Uninstall docker
####################

function uninstall-docker {
  info "Uninstalling docker ..."

  docker stop $(docker ps -q)
  docker rm $(docker ps -aq)

  if [[ $1 == --rmi ]]; then
    docker rmi $(docker image -q)
  fi

  apt remove -y docker-ce docker-ce-cli
  apt autoremove -y

  info "Uninstalling docker ... OK"
}

####################
# Install k3s
####################

function install-k3s {
  info "Installing k3s ..."

  # k3s server
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik" sh -s - --docker

  info "Installing k3s ... OK"
}

####################
# Uninstall k3s
####################

function uninstall-k3s {
  info "Uninstalling k3s ..."

  /usr/local/bin/k3s-uninstall.sh

  info "Uninstalling k3s ... OK"
}

####################
# Setup network
####################

function setup-network {
  info "Setting up network ..."

  # kubectl create ns ambassador
  kubectl apply -f https://www.getambassador.io/yaml/ambassador/ambassador-crds.yaml
  kubectl apply -f https://www.getambassador.io/yaml/ambassador/ambassador-rbac.yaml
  kubectl apply -f conf/ambassador-service.yaml

  openssl req -x509 -newkey rsa:4096 -keyout ${DEPLOY_LOCAL_WORKDIR}/key.pem -out ${DEPLOY_LOCAL_WORKDIR}/cert.pem -subj '/CN=ambassador-cert' -nodes
  kubectl create secret tls tls-cert --cert=${DEPLOY_LOCAL_WORKDIR}/cert.pem --key=${DEPLOY_LOCAL_WORKDIR}/key.pem
  kubectl apply -f conf/wildcard-host.yaml

  info "Setting up network ... OK"
}

####################
# Install helm
####################

HELM3=${TOOLS_HOST_DIR}/helm-${HELM3_VERSION}
HELM=${HELM3}

function install-helm {
  info "Installing helm3 ${HELM3_VERSION} ..."

  if [[ ! -f ${HELM3} ]]; then
    mkdir -p ${TOOLS_HOST_DIR}/tmp-helm3
    curl -fsSL https://get.helm.sh/helm-${HELM3_VERSION}-${SAFEHOSTPLATFORM}.tar.gz | tar -xz -C ${TOOLS_HOST_DIR}/tmp-helm3
    mv ${TOOLS_HOST_DIR}/tmp-helm3/${SAFEHOSTPLATFORM}/helm ${HELM3}
    rm -fr ${TOOLS_HOST_DIR}/tmp-helm3
  else
    echo "helm3 ${HELM3_VERSION} detected."
  fi

  info "Installing helm3 ${HELM3_VERSION} ... OK"
}

####################
# Setup filesystem
####################

function setup-filesystem {
  if [ ! -d "/mnt/data" ]; then
    info "Setting up filesystem ..."

    mkdir -p /mnt/data        # elastic, cockroachdb and kafka data dir
    mkdir -p /mnt/metrics     # cassandra data dir
    mkdir -p /mnt/traces      # clickhouse data dir
    mkdir -p /var/log/instana # log dir for db's

    if [ -e "/dev/vdb" ]; then
      mkfs.xfs /dev/vdb
      mount /dev/vdb /mnt/data
    fi
    if [ -e "/dev/vdc" ]; then
      mkfs.xfs /dev/vdc
      mount /dev/vdc /mnt/metrics
    fi
    if [ -e "/dev/vdd" ]; then
      mkfs.xfs /dev/vdd
      mount /dev/vdd /mnt/traces
    fi
    if [ -e "/dev/vde" ]; then
      mkfs.xfs /dev/vde
      mount /dev/vde /var/log/instana
    fi

    info "Setting up filesystem ... OK"
  fi
}


####################
# Install NFS
####################

NFS_PATH="/mnt/nfs_share"

function install-nfs {
  info "Installing nfs-kernel-server ..."

  install-apt-package "nfs-kernel-server"

  info "Installing nfs-kernel-server ... OK"

  info "Setting up nfs share ..."

  echo "Create root NFS directory"
  mkdir -p ${NFS_PATH}
  chown nobody:nogroup ${NFS_PATH} # No-one is owner
  chmod 777 ${NFS_PATH}            # Everyone can modify files

  echo "Define access for NFS clients in export file /etc/exports"
  if ! cat /etc/exports | grep -q "${NFS_PATH}"; then
    echo "${NFS_PATH} *(rw,sync,no_root_squash,no_all_squash,no_subtree_check)" >> /etc/exports

    echo "Make the nfs share available to clients"
    exportfs -a                         # Making the file share available
    systemctl restart nfs-kernel-server # Restarting the NFS kernel
  fi

  info "Setting up nfs share ... OK"
}

####################
# Install Instana Console
####################

function install-instana-console {
  
  add-apt-source "instana-product.list" \
    "deb [arch=amd64] https://self-hosted.instana.io/apt generic main" \
    "https://self-hosted.instana.io/signing_key.gpg"

  apt update >/dev/null 2>&1

  if [ -z "$1" ]; then
    LATEST_KUBECTL_MARJOR_VERSION=`apt list -a instana-kubectl -q=0 2>&1 | grep Done -A 1 | grep instana | cut -d' ' -f2 | cut -d'-' -f1`
    INSTANA_CONSOLE_VERSION=`apt list -a instana-console -q=2 2>&1 | grep $LATEST_KUBECTL_MARJOR_VERSION | head -n 1 | cut -d' ' -f2`
  else
    INSTANA_CONSOLE_VERSION=$1
  fi

  info "Installing Instana console ${INSTANA_CONSOLE_VERSION} ..."

  install-apt-package "instana-console" ${INSTANA_CONSOLE_VERSION}

  info "Installing Instana console ${INSTANA_CONSOLE_VERSION} ... OK"
}

####################
# Uninstall Instana Console
####################

function uninstall-instana-console {
  INSTANA_CONSOLE_VERSION=`instana version | cut -d' ' -f3`
  info "Uninstalling Instana console ${INSTANA_CONSOLE_VERSION} ..."

  apt remove -y instana-console

  info "Uninstalling Instana console ${INSTANA_CONSOLE_VERSION} ... OK"
}

####################
# Install Instana DB
####################

function install-instana-db {
  INSTANA_CONSOLE_VERSION=`instana version | cut -d' ' -f3`
  info "Installing Instana DB ${INSTANA_CONSOLE_VERSION} ..."

  echo "Installing Instana DB using the provided settings ..."
  INSTANA_DB_HOST=${INSTANA_DB_HOST:-$(hostname)}

  cat ${ROOT_DIR}/conf/settings-db.hcl.tpl | \
    sed -e "s|@@INSTANA_DOWNLOAD_KEY|${INSTANA_DOWNLOAD_KEY}|g; \
      s|@@INSTANA_DB_HOST|${INSTANA_DB_HOST}|g;" > ${DEPLOY_LOCAL_WORKDIR}/settings-db.hcl

  instana datastores init --file ${DEPLOY_LOCAL_WORKDIR}/settings-db.hcl --force

  info "Installing Instana DB ${INSTANA_CONSOLE_VERSION} ... OK"
}

####################
# Clean Instana DB
####################

function clean-instana-db {
  info "Cleaning Instana DB ..."

  local db_layer=(
    instana-cockroachdb
    instana-elastic
    instana-cassandra
    instana-kafka
    instana-clickhouse
    instana-zookeeper
  )

  for db in ${db_layer[@]}; do
    if docker container inspect $db >/dev/null 2>&1; then
      echo "Stopping container $db ..."
      docker stop $db
      echo "Removing container $db ..."
      docker rm $db
    fi
  done

  echo "Deleting db data ..."
  rm -r /mnt/metrics/* 2>/dev/null
  rm -r /mnt/traces/* 2>/dev/null
  rm -r /mnt/data/* 2>/dev/null
  rm -r /mnt/log/* 2>/dev/null

  info "Cleaning Instana DB ... OK"
}

####################
# Install NFS provisioner
####################

function install-nfs-provisioner {
  info "Installing NFS provisioner ..."

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  local helm_repository_name="nfs-subdir-external-provisioner"
  local helm_repository_url="https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  local helm_release_name="nfs-subdir-external-provisioner"
  local helm_release_namespace="default"
  local helm_chart_name="nfs-subdir-external-provisioner"

  install-helm-release \
    ${helm_repository_name} ${helm_repository_url} \
    ${helm_release_name} ${helm_release_namespace} ${helm_chart_name} \
    --set nfs.server=${NFS_HOST} --set nfs.path=${NFS_PATH}

  info "Installing NFS provisioner ... OK"
}

####################
# Install Instana kubectl plugin
####################

function install-kubectl-instana-plugin {
  INSTANA_KUBECTL_PLUGIN_VERSION=$1
  info "Installing Instana kubectl plugin ${INSTANA_KUBECTL_PLUGIN_VERSION} ..."

  add-apt-source "instana-product.list" \
    "deb [arch=amd64] https://self-hosted.instana.io/apt generic main" \
    "https://self-hosted.instana.io/signing_key.gpg"

  apt update >/dev/null 2>&1

  install-apt-package "instana-kubectl" ${INSTANA_KUBECTL_PLUGIN_VERSION}

  info "Installing Instana kubectl plugin ${INSTANA_KUBECTL_PLUGIN_VERSION} ... OK"
}

####################
# Uninstall Instana kubectl plugin
####################

function uninstall-kubectl-instana-plugin {
  INSTANA_KUBECTL_PLUGIN_VERSION=`kubectl instana --version | grep commit | cut -d' ' -f2`
  info "Uninstalling Instana kubectl plugin ${INSTANA_KUBECTL_PLUGIN_VERSION} ..."

  apt remove -y instana-kubectl

  info "Uninstalling Instana kubectl plugin ${INSTANA_KUBECTL_PLUGIN_VERSION} ... OK"
}

####################
# Download Instana license
####################

function download-instana-license {
  info "Downloading Instana license ..."

  curl https://instana.io/onprem/license/download?salesId=${INSTANA_SALES_KEY} -o ${DEPLOY_LOCAL_WORKDIR}/license

  info "Downloading Instana license ... OK"
}

####################
# Install Instana
####################

function install-instana {
  INSTANA_VERSION=`kubectl instana --version | grep commit | cut -d' ' -f2`
  info "Installing Instana ${INSTANA_VERSION} ..."

  echo "Creating self-signed certificate ..."
  if [[ ! -f ${DEPLOY_LOCAL_WORKDIR}/tls.key || ! -f ${DEPLOY_LOCAL_WORKDIR}/tls.crt ]]; then
    openssl req -x509 -newkey rsa:2048 -keyout ${DEPLOY_LOCAL_WORKDIR}/tls.key -out ${DEPLOY_LOCAL_WORKDIR}/tls.crt -days 365 -nodes -subj "/CN=*.${INSTANA_FQDN}"
  else
    echo "Self-signed certificate detected"
  fi

  echo "Generating dhparams ..."
  if [[ ! -f ${DEPLOY_LOCAL_WORKDIR}/dhparams.pem ]]; then
    openssl dhparam -out ${DEPLOY_LOCAL_WORKDIR}/dhparams.pem 1024
  else
    echo "dhparams detected"
  fi

  echo "Applying Instana using the provided settings ..."
  INSTANA_DB_HOSTIP="$(host ${INSTANA_DB_HOST} | awk '/has.*address/{print $NF; exit}')"
  INSTANA_LICENSE=${DEPLOY_LOCAL_WORKDIR}/license
  INSTANA_SETTINGS=${ROOT_DIR}/conf/settings.hcl.tpl
  cat ${INSTANA_SETTINGS} | \
    sed -e "s|@@INSTANA_DOWNLOAD_KEY|${INSTANA_DOWNLOAD_KEY}|g; \
      s|@@INSTANA_SALES_KEY|${INSTANA_SALES_KEY}|g; \
      s|@@INSTANA_LICENSE|${INSTANA_LICENSE}|g; \
      s|@@INSTANA_FQDN|${INSTANA_FQDN}|g; \
      s|@@INSTANA_DB_HOSTIP|${INSTANA_DB_HOSTIP}|g; \
      s|@@ROOT_DIR|${ROOT_DIR}|g; \
      s|@@DEPLOY_LOCAL_WORKDIR|${DEPLOY_LOCAL_WORKDIR}|g;" > ${DEPLOY_LOCAL_WORKDIR}/settings.hcl
  kubectl instana apply --yes --settings-file ${DEPLOY_LOCAL_WORKDIR}/settings.hcl

  wait-ns instana-core

  wait-deployment acceptor instana-core
  wait-deployment ingress-core instana-core
  wait-deployment ingress instana-units

  cat $ROOT_DIR/conf/mappings.yaml | \
    sed -e "s|@@INSTANA_FQDN|${INSTANA_FQDN}|g" > ${DEPLOY_LOCAL_WORKDIR}/mappings.yaml

  kubectl apply -f ${DEPLOY_LOCAL_WORKDIR}/mappings.yaml
  kubectl apply -f conf/nodeport.yaml

  info "Installing Instana ${INSTANA_VERSION} ... OK"
}

####################
# Uninstall Instana
####################

function uninstall-instana {
  INSTANA_VERSION=`kubectl instana --version | grep commit | cut -d' ' -f2`
  info "Uninstalling Instana ${INSTANA_VERSION} ..."

  kubectl delete unit.instana.io instana-prod -n instana-units
  wait-ns-empty instana-units

  kubectl delete core.instana.io instana-core -n instana-core
  wait-ns-empty instana-core

  kubectl delete deployment instana-selfhosted-operator -n instana-operator

  info "Uninstalling Instana ${INSTANA_VERSION} ... OK"
}

####################
# Print summary after install
####################

function print-summary-db {
  cat << EOF

👏 Congratulations! The Single-hosted Instana Database Layer is available!
It installed following tools and applitions:
- Self-hosted Instana Database Layer (Build ${INSTANA_CONSOLE_VERSION})

EOF
}

function print-summary-instana {
  cat << EOF

👏 Congratulations! The Self-hosted Instana on Kubernetes is available!
It launched a kind cluster, installed following tools and applitions:
- helm ${HELM3_VERSION}
- Self-hosted Instana on Kubernetes (Build ${INSTANA_VERSION})

To access Instana UI, open https://${INSTANA_FQDN} in browser.
- username: admin@instana.local
- password: passw0rd

EOF
}

function print-elapsed {
  elapsed_time=$(($SECONDS - $start_time))
  echo "Total elapsed time: $elapsed_time seconds"
}

####################
# Print help
####################

function print-help {
  cat << EOF
The self-hosted K8s Instana deloyment on single or dual nodes

Help you install the single-hosted Instana database layer on one machine and the
self-hosted Instana for Kubernetes in a k3s cluster.

Usage: $0 [up|down] [k3s|db|instana] <version>

Examples:
  # Bring up a single node k3s cluster over docker
  $0 up k3s
  # Bring up single-hosted Instana database layer on your machine, version such as 207-3, latest if omitted
  $0 up db <version>
  # Bring up self-hosted Instana for Kubernetes, version such as 207-3, latest if omitted
  $0 up instana <version>
  # Take down self-hosted Instana for Kubernetes and remove instana-kubectl
  $0 down instana
  # Take down single-hosted Instana database layer and remove instana-console
  $0 down db
  # Remove entire k3s cluster and docker from your machine
  $0 down k3s
EOF
}

####################
# Main entrance
####################

start_time=$SECONDS

action=$1; shift
target=$1; shift

case $action in
  "up")
    case $target in
      "k3s")
        install-docker
        install-k3s
        setup-network
        install-nfs
        install-helm
        install-nfs-provisioner
        ;;
      "db")
        preflight-check-key
        install-docker
        setup-filesystem
        install-instana-console $@
        install-instana-db
        print-summary-db
        print-elapsed
        ;;
      "instana")
        preflight-check-key
        preflight-check-db
        install-kubectl-instana-plugin $@
        download-instana-license
        install-instana
        print-summary-instana
        print-elapsed
        ;;
      *)
        print-help
        ;;
    esac
    ;;
  "down")
    case $target in
      "k3s")
        uninstall-k3s
        uninstall-docker $@
        ;;
      "db")
        clean-instana-db
        uninstall-instana-console
        ;;
      "instana")
        uninstall-instana
        uninstall-kubectl-instana-plugin
        ;;
      *)
        print-help
        ;;
    esac
    ;;
  *)
    print-help
    ;;
esac
