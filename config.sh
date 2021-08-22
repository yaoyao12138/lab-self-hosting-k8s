# The version of kind
KIND_VERSION=${KIND_VERSION:-v0.11.1}
# The version of kubectl
KUBECTL_VERSION=${KUBECTL_VERSION:-v1.17.11}
# The version of helm
HELM3_VERSION=${HELM3_VERSION:-v3.5.3}
# The version of nfs-subdir-external-provisioner 
NFS_PROVISIONER_VERSION=${NFS_PROVISIONER_VERSION:-4.0.13}

###################
# Instana settings
###################

# The version of Instana
INSTANA_VERSION=${INSTANA_VERSION:-205-2}
# Your Instana hostname
INSTANA_HOST=${INSTANA_HOST:-$(hostname)}
# Your Instana db hostname
INSTANA_DB_HOST=${INSTANA_DB_HOST:-$(hostname)}
# Your Instana license file
INSTANA_LICENSE=
# Your Instana download key
INSTANA_DOWNLOAD_KEY="your download key"
# Your Instana sales key
INSTANA_SALES_KEY="your sales key"
# Your NFS hostname
NFS_HOST=${NFS_HOST:-INSTANA_DB_HOST}
