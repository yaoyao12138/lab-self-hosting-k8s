admin_password = "passw0rd"                        # The initial password the administrator will receive
download_key = "@@INSTANA_DOWNLOAD_KEY"            # Provided by instana
sales_key = "@@INSTANA_SALES_KEY"                  # This identifies you as our customer and is required to activate your license
base_domain = "@@INSTANA_FQDN"                     # The domain under which instana will be reachable
core_name = "instana-core"                         # A name identifiying the Core CRD created by the operator. This needs to be unique if you have more than one instana installation running
tls_crt_path = "@@DEPLOY_LOCAL_WORKDIR/tls.crt"    # Path to the certificate to be used for the HTTPS endpoints of instana
tls_key_path = "@@DEPLOY_LOCAL_WORKDIR/tls.key"    # Path to the key to be used for the HTTPS endpoints of instana
license = "@@INSTANA_LICENSE"                      # License file
dhparams = "@@DEPLOY_LOCAL_WORKDIR/dhparams.pem"   # Diffie–Hellman params for improved connection security
email {                                            # configure this so instana can send alerts and invites
  user = "<user_name>>"
  password = "<user_password>>"
  host = "<smtp_host_name>"
}
token_secret = "randomstring"                      # Secret for generating the tokens used to communicate with instana
databases "cassandra"{                             # Database definitions, see below the code block for a detailed explanation.
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
databases "cockroachdb"{
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
databases "clickhouse"{
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
databases "elasticsearch"{
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
databases "kafka"{
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
databases "zookeeper"{
    nodes = ["@@INSTANA_DB_HOSTIP"]
}
profile = "small"                                  # Specify the memory/cpu-profile to be used for components
spans_location {                                   # Spans can be stored in either s3 or on disk, this is an s3 example
    persistent_volume {                            # Use a persistent volume for raw-spans persistence 
        storage_class = "nfs-client"               # Storage class to be used 
    } 
}
ingress "agent-ingress" {                          # This block defines the public reachable name where the agents will connect 
    hostname = "@@INSTANA_FQDN"
    port     = 8600
}
units "prod" {                                     # This block defines a tenant unit named prod associated with the tenant instana
    tenant_name       = "instana"
    initial_agent_key = "@@INSTANA_DOWNLOAD_KEY"
    profile           = "small"
}
enable_network_policies = false                    # If set to true network policies will be installed (optional)
