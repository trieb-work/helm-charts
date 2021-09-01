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
AWS_ACCESS_SECRET
AWS_ENDPOINT
AWS_BUCKET
```
Installation: 

```
helm install saleor trieb.work/strapi
```
