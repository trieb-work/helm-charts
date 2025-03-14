# Saleor Apps Helm Chart

This Helm chart deploys the official Saleor Apps to a Kubernetes cluster. It supports multiple apps that can be enabled or disabled as needed, with a shared Redis instance for persistence (APL).

## Available Apps

- **CRM Klaviyo**: Integration with Klaviyo CRM
- **SMTP**: Email sending functionality
- **Products Feed**: Product feed generation and management
- **Search**: Provides search functionality
- **Avatax**: Tax calculations via Avatax
- **CMS v2**: Content Management System

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
| `global.secretKey` | Secret key for app security | `""` |

### Redis Configuration

The chart supports both internal and external Redis configurations. You can either:
1. Use the built-in Redis (default)
2. Connect to an external Redis instance

#### Using External Redis

To use an external Redis instance, simply set the full Redis URL in the global configuration:

```yaml
global:
  redisUrl: "redis://user:password@your-redis-host:6379"
```

This takes precedence over any internal Redis configuration.

#### Using Internal Redis

By default, the chart will deploy a Redis instance using the Bitnami Redis chart. You can configure authentication:

```yaml
redis:
  auth:
    enabled: true  # Enable Redis password authentication
    password: "your-password"  # Set your Redis password
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.redisUrl` | External Redis URL (takes precedence if set) | `""` |
| `redis.enabled` | Enable internal Redis deployment | `true` |
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

### Avatax DynamoDB Support

The Avatax app can optionally use DynamoDB for storing client logs. When enabled, the chart will:

1. Deploy a local DynamoDB instance
2. Create a table for Avatax client logs
3. Configure the Avatax app to use this DynamoDB instance

#### Configuration

Enable and configure DynamoDB for Avatax in your values.yaml:

```yaml
apps:
  app-avatax:
    enabled: true
    hostname: avatax.your-domain.com
    # Enable the built-in DynamoDB deployment
    dynamodb:
      enabled: true
      # Optional: customize these settings if needed
      logsTableName: "avatax-client-logs"
      logsItemTtlInDays: 14
      region: "us-east-1"
      # Optional: provide your own AWS credentials
      # accessKeyId: "your-access-key"
      # secretAccessKey: "your-secret-key"
```

When DynamoDB is enabled:
1. A DynamoDB local instance is deployed in your cluster
2. The required table is automatically created during installation
3. All necessary environment variables are set on the Avatax app
4. No additional configuration is needed for the app to work with DynamoDB

#### Using with External AWS DynamoDB

If you want to use an external AWS DynamoDB instance instead of the local one:

1. Set `apps.app-avatax.dynamodb.enabled` to `false`
2. Provide the AWS credentials and region
3. Set the appropriate environment variables in the Avatax app configuration

#### AWS Credentials

By default, the chart uses dummy credentials ("dynamodb-local") for local development and testing. For production environments, you should provide actual AWS credentials.

## Marketplace Service

The chart includes a marketplace service that provides a custom marketplace JSON endpoint for your Saleor apps. This allows you to have a self-hosted marketplace that lists all your enabled Saleor apps with their correct manifest URLs.

### Configuration

Enable and configure the marketplace in your values.yaml:

```yaml
marketplace:
  # Enable or disable the marketplace service
  enabled: true
  # Your marketplace hostname
  hostname: marketplace.apps.example.com
  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod  # Optional: for automatic SSL
    tls:
      enabled: true
      secretName: ""  # Leave empty to use default name: <release>-marketplace-tls
```

### Usage with Saleor Dashboard

To use your custom marketplace with Saleor Dashboard, set the `APPS_MARKETPLACE_API_URL` environment variable in your dashboard deployment:

```yaml
env:
  - name: APPS_MARKETPLACE_API_URL
    value: "https://marketplace.apps.example.com/marketplace.json"
```

This will allow you to install your apps directly from the Saleor Dashboard with one click. The marketplace JSON will only include apps that are enabled in your saleor-apps deployment.

### Marketplace JSON Format

The marketplace service generates a JSON file that follows the official Saleor marketplace format. For each enabled app, it includes:
- App name and description
- Logo and branding information
- Integration details
- Manifest URL pointing to your deployed app instance
- Standard privacy and support URLs

The manifest URLs are automatically set to match your app hostnames as configured in the chart.

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
