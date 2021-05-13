# README

## Steps

* syncs exports from GCS to local dir
* loops over local cache dir of exports
  * parses findings into prometheus formatted metrics
  * pushes them into pushgateway with timestamp (back dated)
* pushgateway plumbed to prometheus TSDB
* Grafana plumbed to prometheus
* Grafana dashboards
