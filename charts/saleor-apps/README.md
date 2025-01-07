# Saleor Apps Helm Chart

This Helm chart deploys Saleor Apps to a Kubernetes cluster. It supports multiple apps that can be enabled or disabled as needed, with a shared Redis instance for persistence.

## Available Apps

- **CRM Klaviyo**: Integration with Klaviyo CRM
- **Emails and Messages**: Handles email and messaging functionality
- **Invoices**: Manages invoice generation and processing
- **Search**: Provides search functionality
- **Taxes**: Handles tax calculations and management
- **Webhook**: Manages webhook integrations

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Ingress controller (e.g., nginx-ingress)

## Dependencies

- Redis (Bitnami chart)

## Installation

1. Add the Bitnami repository for Redis dependency:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

2. Create a values file (e.g., `my-values.yaml`) to configure your deployment:
```yaml
global:
  domain: "your-domain.com"
  secretKey: "your-secret-key"  # Required for app security

redis:
  auth:
    password: "your-redis-password"  # Set a secure password

# Enable the apps you need
apps:
  crm-klaviyo:
    enabled: true
    hostname: crm-klaviyo.your-domain.com
  emails-and-messages:
    enabled: true
    hostname: emails.your-domain.com
  # ... configure other apps as needed
```

3. Install the chart:
```bash
helm install saleor-apps . -f my-values.yaml
```

## Configuration

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Base domain for all apps | `apps.example.com` |
| `global.secretKey` | Secret key for app security | `""` |

### Redis Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Enable Redis deployment | `true` |
| `redis.auth.enabled` | Enable Redis authentication | `true` |
| `redis.auth.password` | Redis password | `""` |

### Common App Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `common.image.registry` | Docker registry | `ghcr.io` |
| `common.image.repository` | Docker repository | `trieb-work/saleor-apps-docker` |
| `common.image.tag` | Docker image tag | `latest` |
| `common.image.pullPolicy` | Image pull policy | `IfNotPresent` |

### App-Specific Configuration

Each app supports the following configuration parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `apps.<app-name>.enabled` | Enable the app | `false` |
| `apps.<app-name>.hostname` | Hostname for the app | `<app>.apps.example.com` |
| `apps.<app-name>.port` | Container port | `3000` |
| `apps.<app-name>.ingress.enabled` | Enable ingress | `true` |
| `apps.<app-name>.ingress.annotations` | Ingress annotations | `{}` |

## Usage

1. After installation, each enabled app will be available at its configured hostname.
2. All apps share the same Redis instance for persistence.
3. Configure your DNS to point the hostnames to your ingress controller.

## Upgrading

To upgrade the release:

```bash
helm upgrade saleor-apps . -f my-values.yaml
```

## Uninstallation

To uninstall the release:

```bash
helm uninstall saleor-apps
```

## Notes

- The Redis password must be set before installation
- Each app requires its own hostname for ingress
- The secret key should be securely generated and kept private
- All apps use port 3000 by default inside their containers
