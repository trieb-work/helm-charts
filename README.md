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
```
helm install saleor trieb.work/strapi
```
