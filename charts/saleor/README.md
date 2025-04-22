# Saleor Helm Chart

This is a community-maintained Helm chart for deploying [Saleor](https://saleor.io), a modular, high performance, headless e-commerce platform built with Python, GraphQL, Django, and React. This chart is not officially associated with or maintained by the Saleor team.

## Features

- Full Saleor stack deployment (API, Dashboard, Worker)
- Production-grade PostgreSQL configuration with read replica support
- Redis for caching and Celery tasks
- Service mesh integration for improved performance
- Horizontal Pod Autoscaling
- Configurable resource management
- Comprehensive security settings

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure
- Istio (optional, for service mesh features)

## Quick Start

1. Add the Helm repository:
```bash
helm repo add trieb-work https://trieb-work.github.io/helm-charts
helm repo update
```

2. Install the chart:
```bash
helm install my-saleor trieb-work/saleor
```

## Architecture

The chart deploys the following components:

- Saleor API server
- Saleor Dashboard
- Celery workers
- PostgreSQL database (optional)
- Redis (optional)
- Service mesh configuration (optional)

## Configuration

### Global Configuration

```yaml
global:
  # -- Global image pull secrets
  imagePullSecrets: []
  # -- Storage class to use for persistent volumes
  storageClass: ""
  # -- External Database URL (if not using internal PostgreSQL)
  databaseUrl: ""
  # -- External Redis URL (if not using internal Redis)
  redisUrl: ""
  # -- RSA private key for JWT signing
  jwtRsaPrivateKey: ""
  # -- Global TLS certificate configuration
  tls:
    # -- Enable global TLS certificate
    enabled: false
    # -- Existing TLS secret name to use for all ingress resources
    secretName: "my-wildcard-tls-secret"
  
  database:
    primaryUrl: ""        # External primary database URL
    replicaUrl: ""        # External read replica URL
    maxConnections: 150
    connectionTimeout: 5
```

The `global.tls` configuration allows you to enable a global TLS certificate for all ingress resources. When enabled, you can specify an existing TLS secret name to use for all ingress resources. This can be useful for deploying a wildcard TLS certificate for your domain.

### JWT Configuration

Saleor uses RSA private/public key pairs for JWT token signing. You must configure this for production deployments. Here's how to set it up:

1. Generate a new RSA key pair (if you don't have one):
   ```bash
   # Generate private key
   openssl genrsa -out private.pem 4096
   # Generate public key
   openssl rsa -in private.pem -pubout -out public.pem
   ```

2. Add the private key to your values file:
   ```yaml
   global:
     jwtRsaPrivateKey: |
       -----BEGIN PRIVATE KEY-----
       Your RSA private key here
       -----END PRIVATE KEY-----
   ```

The private key will be automatically mounted in both the API and worker services. Keep your private key secure and never commit it to version control.

Note: If `jwtRsaPrivateKey` is not set, Saleor will use a temporary key in development mode, but this is not suitable for production use.

### Database Configuration

The chart offers several options for configuring the database, including support for read replicas:

#### 1. Using the Built-in PostgreSQL Database

By default, the chart will deploy a PostgreSQL instance and automatically manage the credentials:

```yaml
postgresql:
  enabled: true
  # Choose between standalone or replication architecture
  architecture: replication  # or 'standalone'
  auth:
    username: saleor
    database: saleor
    # Optional: Provide specific passwords, otherwise they will be auto-generated
    existingSecret: postgresql-credentials
    secretKeys:
      userPasswordKey: password
      adminPasswordKey: postgresql-password
      replicationPasswordKey: replication-password  # Required for replication
  
  # Primary database configuration
  primary:
    persistence:
      size: 50Gi
    resources:
      requests:
        cpu: 2
        memory: 4Gi
  
  # Read replica configuration (only used when architecture: replication)
  readReplicas:
    replicaCount: 1
    persistence:
      size: 50Gi
```

When using the built-in PostgreSQL with `architecture: replication`:
- A read-only replica service is created at `<release>-postgresql-read`
- Saleor automatically uses this replica for read operations to reduce load on the primary
- The primary database at `<release>-postgresql-primary` is still used for all write operations

The PostgreSQL credentials are stored in a Kubernetes secret named `postgresql-credentials`. This secret is marked with `helm.sh/resource-policy: keep` to ensure the credentials persist across Helm upgrades.

#### 2. Using an External Database

To use an external database, disable the built-in PostgreSQL and provide your database URLs:

```yaml
postgresql:
  enabled: false

global:
  database:
    primaryUrl: "postgresql://user:password@your-db-host:5432/saleor"
    replicaUrl: "postgresql://user:password@your-read-replica:5432/saleor"  # Optional
    maxConnections: 150
    connectionTimeout: 5
```

When configuring external databases:
- The `primaryUrl` is required and will be used for all operations if no replica is configured
- The `replicaUrl` is optional - when provided, Saleor will use it for read operations to reduce load on the primary
- Only a single read replica is supported

#### Managing Database Credentials

If you're using the built-in PostgreSQL, you have two options for managing credentials:

1. **Auto-generated passwords**: If you don't provide passwords, they will be automatically generated during installation
2. **Manual secret management**: Create the secret before installation:
   ```bash
   kubectl create secret generic postgresql-credentials \
     --from-literal=password=user-password \
     --from-literal=postgresql-password=admin-password \
     --from-literal=replication-password=replication-password  # Only needed for replication
   ```

Important notes about database passwords:
- Generated passwords are preserved across Helm upgrades via the `helm.sh/resource-policy: keep` annotation
- To rotate passwords:
  1. Delete the existing `postgresql-credentials` secret
  2. Either let the chart generate new passwords or provide new ones in your values
  3. Upgrade the release

### Redis Configuration

The chart offers several options for configuring Redis:

#### 1. Using the Built-in Redis

By default, the chart will deploy a Redis instance using the Bitnami Redis chart:

```yaml
redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: true
    # Optional: Provide a specific password
    password: "your-password"  # If not set, a random password will be generated
  master:
    persistence:
      size: 8Gi
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
```

The Redis password is stored in a Kubernetes secret and will be preserved across Helm upgrades.

#### 2. Using an External Redis

To use an external Redis instance, disable the built-in Redis and configure the external connection:

```yaml
redis:
  enabled: false
  external:
    host: "my-redis.example.com"
    port: 6379
    database: 0
    username: "redis-user"  # Optional, for Redis ACLs
    password: "redis-password"
    tls:
      enabled: false  # Set to true for TLS/SSL connections
```

#### 3. Using a Global Redis URL

For complete control over the Redis URL, you can provide it directly:

```yaml
global:
  redisUrl: "redis://user:password@redis.example.com:6379/0"
  # Or with TLS:
  # redisUrl: "rediss://user:password@redis.example.com:6379/0"
```

### Important Notes About Redis Configuration

- If using built-in Redis without a specified password, a random one will be generated during first installation
- The generated password will be preserved across Helm upgrades
- Redis URL format: `redis[s]://[username][:password]@host:port/database`
  - Use `redis://` for standard connections
  - Use `rediss://` for TLS/SSL connections
  - Username is optional and only needed for Redis ACLs
  - Database number is optional (defaults to 0)
- When using external Redis with TLS:
  - Set `redis.external.tls.enabled: true`
  - The connection will use the `rediss://` protocol
  - You can optionally skip TLS verification with `redis.external.tls.insecureSkipVerify: true`

### API Configuration

```yaml
api:
  enabled: true
  replicaCount: 1
  
  image:
    repository: ghcr.io/saleor/saleor
    tag: "3.19.0"
  
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
  
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 5
```

### Dashboard Configuration

```yaml
dashboard:
  enabled: true
  replicaCount: 1
  
  image:
    repository: ghcr.io/saleor/saleor-dashboard
    tag: "3.19.0"
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
```

### Worker Configuration

```yaml
worker:
  enabled: true
  replicaCount: 1
  
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
  
  autoscaling:
    enabled: false
    minReplicas: 1
    maxReplicas: 3
```

### Service Mesh Configuration

```yaml
serviceMesh:
  enabled: false
  istio:
    enabled: false
    api:
      circuitBreaker:
        enabled: true
        maxConnections: 100
      timeout:
        enabled: true
        http: 10s
```

### Storage Configuration

The chart supports both S3-compatible storage and Google Cloud Storage (GCS) for storing media and static files.

#### Amazon S3 Configuration

Enable S3 storage by configuring the following in your values file:

```yaml
storage:
  s3:
    enabled: true
    credentials:
      accessKeyId: "your-access-key"
      secretAccessKey: "your-secret-key"
    config:
      region: "us-east-1"
      bucketName: "your-bucket-name"
      # Optional configurations
      staticBucketName: "your-static-bucket"    # Separate bucket for static files
      mediaBucketName: "your-media-bucket"      # Separate bucket for media files
      mediaPrivateBucketName: "private-bucket"  # Separate bucket for private media
      customDomain: "cdn.yourdomain.com"        # Custom domain for serving files
      defaultAcl: "public-read"
      queryStringAuth: false
```

For more details on S3 configuration, see the [official Saleor documentation](https://docs.saleor.io/setup/media-s3).

#### Google Cloud Storage Configuration

To use Google Cloud Storage, configure the following:

```yaml
storage:
  gcs:
    enabled: true
    # When running on GKE with Workload Identity (recommended)
    serviceAccount:
      create: true
      annotations:
        iam.gke.io/gcp-service-account: saleor-gcs@YOUR_PROJECT_ID.iam.gserviceaccount.com
    
    config:
      bucketName: "your-bucket-name"
      # Optional configurations
      staticBucketName: "your-static-bucket"
      mediaBucketName: "your-media-bucket"
      mediaPrivateBucketName: "private-bucket"
      customDomain: "cdn.yourdomain.com"
      defaultAcl: "publicRead"
```

For more details on GCS configuration, see the [official Saleor documentation](https://docs.saleor.io/setup/media-gcs).

### Complete S3 Configuration Example

Here's a complete example of S3 configuration using CloudFront for content delivery:

```yaml
storage:
  s3:
    enabled: true
    credentials:
      accessKeyId: "AKIAIOSFODNN7EXAMPLE"
      secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    
    config:
      region: "us-east-1"
      
      # Using separate buckets for different types of content
      staticBucketName: "my-shop-static"     # Public bucket for static files
      mediaBucketName: "my-shop-media"       # Public bucket for uploaded media
      mediaPrivateBucketName: "my-shop-priv" # Private bucket for sensitive data
      
      # Using CloudFront distributions for content delivery
      customDomain: "static.myshop.com"      # CloudFront domain for static files
      mediaCustomDomain: "media.myshop.com"  # CloudFront domain for media files
      
      # Access control
      defaultAcl: "public-read"              # Make files publicly readable
      queryStringAuth: false                 # Disable signed URLs
      queryStringExpire: 3600                # 1 hour expiration for signed URLs (if enabled)
```

Here's an example using MinIO or other S3-compatible storage:

```yaml
storage:
  s3:
    enabled: true
    credentials:
      accessKeyId: "minio-access-key"
      secretAccessKey: "minio-secret-key"
    
    config:
      region: "us-east-1"                    # Required but might not be used
      
      # Using a single bucket with different prefixes
      staticBucketName: "saleor"
      mediaBucketName: "saleor"
      mediaPrivateBucketName: "saleor-private"
      
      # Using custom domains
      customDomain: "storage.example.com"    # Domain for static files
      mediaCustomDomain: "storage.example.com" # Domain for media files
      
      # Access control
      defaultAcl: "public-read"
      queryStringAuth: false
      queryStringExpire: 3600
```

Note: When using CloudFront or another CDN:
1. Configure CORS appropriately for your domains
2. Set up proper cache behaviors for static vs media content
3. For private media, ensure the bucket is not publicly accessible

### Database Migrations

Django requires database migrations to be run after version upgrades. This chart provides two ways to handle migrations:

#### 1. Automatic Migrations (Recommended)

By default, the chart will automatically run migrations after installation and upgrades using a Kubernetes Job:

```yaml
migrations:
  enabled: true  # Enable automatic migrations
  # Additional environment variables specific to migrations
  extraEnv: []   # Add migration-specific env vars if needed
  resources:     # Configure resources for the migration job
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
```

The migration job:
- Runs after install/upgrade using Helm hooks
- Uses the same image and environment variables as the API
- Inherits all environment variables from the API configuration
- Has access to all necessary secrets (database, Redis, JWT, etc.)
- Will be automatically cleaned up after successful completion
- Can be monitored using standard kubectl commands shown in the post-install notes

#### 2. Manual Migrations

If you prefer to run migrations manually (e.g., in highly controlled environments), disable automatic migrations:

```yaml
migrations:
  enabled: false
```

Then run migrations manually when needed:

```bash
# Get the API pod name
POD=$(kubectl get pod -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")

# Run migrations
kubectl exec -it $POD -- python manage.py migrate
```

#### Migration Safety

The migration job is designed with safety in mind:
- It runs with `--no-input` to prevent hanging on user input
- It uses the same image and environment as the API to ensure consistency
- It has access to all necessary configuration and secrets
- It's executed after the database is ready but before the new API version starts
- The job history is preserved for debugging purposes

## Mandatory Values & Security

> **Important:** For a successful and secure installation, you must set the following values explicitly:

| Value | Description | Example |
|-------|-------------|---------|
| `global.secretKey` | Django secret key for cryptographic signing | `mySuperSecretKey123` |
| `postgresql.auth.postgresPassword` | PostgreSQL password for the `postgres` user | `strongPostgresPass` |
| `redis.auth.password` | Redis password (if internal Redis is enabled and auth is enabled) | `strongRedisPass` |

- If you do not set these values on first install, the chart will **fail-fast** with a clear error message.
- These values are **never randomly generated** by the chart to prevent accidental credential loss and ensure deterministic, secure deployments.
- For upgrades, the chart will use the existing Kubernetes Secrets if present.

### Example install command

```bash
helm install my-saleor trieb-work/saleor \
  --set global.secretKey="mySuperSecretKey123" \
  --set postgresql.auth.postgresPassword="strongPostgresPass" \
  --set redis.auth.password="strongRedisPass"
```

### Minimal values.yaml example

```yaml
global:
  secretKey: mySuperSecretKey123
postgresql:
  auth:
    postgresPassword: strongPostgresPass
redis:
  auth:
    password: strongRedisPass
```

### Notes
- If using **external PostgreSQL or Redis**, set the corresponding URLs instead and disable the internal services.
- See the [values.yaml](./values.yaml) for all configuration options.

## Getting Started

### Initial Setup

After deploying Saleor for the first time, you'll need to create a superuser (admin) account to access the dashboard:

```bash
# Get the name of the API pod
POD=$(kubectl get pod -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")

# Create a superuser
kubectl exec -it $POD -- python manage.py createsuperuser
```

Follow the prompts to create your admin account. You'll need to provide:
- Email address
- Password (minimum 8 characters)

Once created, you can use these credentials to log into the Saleor Dashboard.

### Configuration

### Security Configuration

#### ALLOWED_HOSTS and CORS

Django requires specific configuration for allowed hosts and CORS. Configure these in your values file:

```yaml
api:
  extraEnv:
    # For production, specify exact hostnames:
    - name: ALLOWED_HOSTS
      value: "your-domain.com,api.your-domain.com"
    - name: ALLOWED_CLIENT_HOSTS
      value: "dashboard.your-domain.com"
    
    # For development only (not recommended for production):
    - name: ALLOWED_HOSTS
      value: "*"
    - name: ALLOWED_CLIENT_HOSTS
      value: "*"
```

**Important Notes:**
- Django's `ALLOWED_HOSTS` does not support wildcards like `*.domain.com`
- You must specify exact hostnames that will be used to access your Saleor instance
- For production, always specify exact domains rather than using `"*"`
- The `ALLOWED_CLIENT_HOSTS` should match the domains from which your dashboard will access the API

### TLS Configuration

The chart supports automatic TLS certificate management using cert-manager. By default, it's configured to use Let's Encrypt production certificates:

```yaml
ingress:
  api:
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: saleor-api-tls
        hosts:
          - your-api-domain.com
  
  dashboard:
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: saleor-dashboard-tls
        hosts:
          - your-dashboard-domain.com
```

**Important Notes:**
- When TLS is enabled (by configuring `ingress.api.tls`), the dashboard will automatically use HTTPS to connect to the API
- The dashboard's `API_URL` environment variable will be set to `https://` or `http://` based on TLS configuration
- Both API and Dashboard should use TLS in production for security

Prerequisites:
1. cert-manager must be installed in your cluster
2. A cluster issuer named "letsencrypt-prod" must be configured

To use a different certificate issuer:
1. Change the `cert-manager.io/cluster-issuer` annotation value
2. Or remove it to use the cluster default
3. Or add `cert-manager.io/issuer` instead to use a namespace issuer

The TLS certificates will be stored in the specified secrets (`saleor-api-tls` and `saleor-dashboard-tls` by default).

## Production Best Practices

### Resource Management

1. Configure appropriate resource requests and limits:
```yaml
api:
  resources:
    requests:
      cpu: 1
      memory: 2Gi
    limits:
      cpu: 2
      memory: 4Gi
```

2. Enable autoscaling:
```yaml
api:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Database Optimization

1. Configure read replicas for improved performance:
```yaml
postgresql:
  architecture: replication
  readReplicas:
    replicaCount: 2
```

2. Optimize PostgreSQL settings:
```yaml
postgresql:
  primary:
    extendedConfiguration: |
      work_mem = 64MB
      maintenance_work_mem = 256MB
      shared_buffers = 3000MB
      max_connections = 150
```

### Security

1. Enable service account:
```yaml
serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: saleor-gcs@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

2. Configure security context:
```yaml
podSecurityContext:
  fsGroup: 1000

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
```

## Monitoring

The chart supports monitoring through various mechanisms:

1. Kubernetes probes
2. PostgreSQL metrics (when enabled)
3. Service mesh telemetry (when enabled)

## Upgrading

### From 0.x to 1.x

Major changes:
- Restructured values.yaml
- Added Dashboard component
- Added service mesh support
- Updated PostgreSQL configuration
- Added read replica support

To upgrade:
1. Backup your values.yaml
2. Review the new values.yaml structure
3. Migrate your configurations
4. Test in a staging environment
5. Upgrade production:
```bash
helm upgrade my-saleor trieb-work/saleor --values values.yaml
```

## Troubleshooting

### Common Issues

1. Database connection issues:
   - Verify database credentials
   - Check network policies
   - Validate connection strings

2. Resource constraints:
   - Monitor resource usage
   - Adjust requests/limits
   - Enable autoscaling

3. Performance issues:
   - Enable read replicas
   - Configure service mesh
   - Optimize PostgreSQL settings

## Support

For issues and feature requests, please:
1. Check the [documentation](https://docs.saleor.io)
2. Open an issue in the [GitHub repository](https://github.com/saleor/saleor)
3. Join the [Saleor community](https://saleor.io/community/)