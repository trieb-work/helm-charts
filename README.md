# trieb.work HELM Charts
This repo is used to create and host our helm charts.

Install our helm repo:

```
helm repo add trieb.work https://trieb-work.github.io/helm-charts/
```

We open-sourced the following charts:

## Saleor
The saleor chart is used to deploy our maintained and stable saleor core with Postgres, Redis and Task Runner (Celery)
```
helm install saleor trieb.work/saleor-helm
```

## Strapi
Use this helm-chart to deploy your own version of strapi. It is intented to be used with your own strapi build. Just make sure, that your docker image makes ues of the following env variables: 
```
ADMIN_JWT_SECRET
DATABASE_URL
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ENDPOINT
AWS_BUCKET
DATABASE_RUN_MIGRATIONS
```

If you want to install a postgres DB together with strapi, just add:
```
--set postgresql.enabled=true
```

Installation: 

```
helm install strapi trieb.work/strapi
```
### Read Replica
You can automatically add read-replicas. It will give you one read-only API endpoint, that is connected to all strapi instances. Just make sure, that
you have the env variable DATABASE_RUN_MIGRATIONS set in the strapi database config for the runMigrations setting, so that this chart can automatically disable the migrations on the read-replica instances.


## Google Tag Manager Server
```
helm install gtm trieb.work/google-tag-manager-server
```
