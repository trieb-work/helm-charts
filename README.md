# trieb.work HELM Charts

This repository hosts our collection of Helm charts for various applications. We maintain these charts with stability and best practices in mind.

## Installation

Add our Helm repository:

```bash
helm repo add trieb.work https://trieb-work.github.io/helm-charts/
```

## Available Charts

### Saleor

A production-ready Helm chart for deploying Saleor Core with PostgreSQL, Redis, and Celery Task Runner.

```bash
helm install saleor trieb.work/saleor-helm
```

For detailed configuration options including storage setup (S3, GCS), database configuration, and more, see our [Saleor Chart Documentation](charts/saleor/README.md).

### Strapi

Deploy your custom Strapi instance with this configurable chart. The chart expects your Docker image to support the following environment variables:

- `ADMIN_JWT_SECRET`
- `DATABASE_URL`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_ENDPOINT`
- `AWS_BUCKET`
- `DATABASE_RUN_MIGRATIONS`

Installation:
```bash
helm install strapi trieb.work/strapi
```

To include PostgreSQL in your deployment:
```bash
helm install strapi trieb.work/strapi --set postgresql.enabled=true
```


### Google Tag Manager Server

Deploy Google Tag Manager Server Side container:
```bash
helm install gtm trieb.work/gtm-server-container-cluster
```

## Contributing

We welcome contributions! Please feel free to submit a Pull Request.
