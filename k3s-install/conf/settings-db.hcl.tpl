type      = "single-db"
host_name = "@@INSTANA_DB_HOST"

dir {
  metrics    = "/mnt/metrics"     // cassandra data dir
  traces     = "/mnt/traces"      // clickhouse data dir
  data       = "/mnt/data"        // elastic, cockroachdb and kafka data dir
  logs       = "/var/log/instana" // log dir for db's
}

docker_repository {
  base_url = "containers.instana.io"
  username = "_"
  password = "@@INSTANA_DOWNLOAD_KEY"
}
