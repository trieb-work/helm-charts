# Saleor-Helm-Chart
This helm chart bootstraps a saleor-core instance to your Kubernetes cluster. Storefront and Dashboard are currently not included.

The service uses a stable saleor-core, ingress, postgreSQL with persistency, celery taskrunner and a redis DB.


## Saleor with Postgres read replication
This helm chart does support the production setup with saleor and a read-replication postgres database. Use the chart in the following way:
```
helm install saleor-replication trieb.work/saleor --set postgresql.architecture="replication"
```