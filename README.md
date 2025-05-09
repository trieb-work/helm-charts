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

### Saleor Apps

Deploy and manage Saleor Apps in your Kubernetes cluster. This chart supports multiple Saleor Apps with individual configurations.

```bash
helm install saleor-apps trieb.work/saleor-apps
```

Key features:
- Deploy multiple Saleor Apps in a single release
- Configure each app independently
- Automatic environment variable management
- Built-in health checks and readiness probes
- Support for custom domains and TLS
- Shared Redis for improved performance

Example configuration:
```yaml
apps:
  search:
    enabled: true
    image:
      repository: ghcr.io/saleor/search
      tag: "3.14.0"
    env:
      - name: SALEOR_API_URL
        value: "https://saleor.example.com/graphql/"
  emails:
    enabled: true
    image:
      repository: ghcr.io/saleor/emails-and-messages
      tag: "3.14.0"
    env:
      - name: SALEOR_API_URL
        value: "https://saleor.example.com/graphql/"
```

This chart is using the docker container from this repository: https://github.com/trieb-work/saleor-apps-docker. You can optionally build them yourself.

For detailed configuration options and examples, see our [Saleor Apps Chart Documentation](charts/saleor-apps/README.md).

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
