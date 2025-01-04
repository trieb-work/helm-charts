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
  
  database:
    primaryUrl: ""        # External primary database URL
    replicaUrls: []      # External read replica URLs
    maxConnections: 150
    connectionTimeout: 5
```

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

### Database Options

#### Internal PostgreSQL

```yaml
postgresql:
  enabled: true
  architecture: replication  # standalone or replication
  auth:
    username: saleor
    database: saleor
    existingSecret: ""
  
  primary:
    persistence:
      size: 50Gi
    resources:
      requests:
        cpu: 2
        memory: 4Gi
    
  readReplicas:
    replicaCount: 1
    persistence:
      size: 50Gi
```

#### External Database

```yaml
postgresql:
  enabled: false

global:
  database:
    primaryUrl: "postgresql://user:pass@primary-db:5432/saleor"
    replicaUrls: 
      - "postgresql://user:pass@replica1-db:5432/saleor"
```

### Database Configuration

The chart offers several options for configuring the database:

#### 1. Using the Built-in PostgreSQL Database

By default, the chart will deploy a PostgreSQL instance and automatically manage the credentials:

```yaml
postgresql:
  enabled: true
  architecture: standalone  # or 'replication' for primary-replica setup
  auth:
    username: saleor
    database: saleor
    # Optional: Provide a specific password
    password: "your-password"  # If not set, a random password will be generated
```

The PostgreSQL credentials are stored in a Kubernetes secret named `postgresql-credentials`. This secret is marked with `helm.sh/resource-policy: keep` to ensure the credentials persist across Helm upgrades.

#### 2. Using an Existing PostgreSQL Secret

If you want to manage the database credentials yourself, you can create a secret named `postgresql-credentials` before installing the chart:

```bash
kubectl create secret generic postgresql-credentials \
  --from-literal=user=saleor \
  --from-literal=database=saleor \
  --from-literal=password=your-password
```

Then configure the chart to use PostgreSQL but without specifying a password:

```yaml
postgresql:
  enabled: true
  auth:
    username: saleor
    database: saleor
```

#### 3. Using an External Database

To use an external database, disable the built-in PostgreSQL and provide your database URL:

```yaml
postgresql:
  enabled: false

global:
  database:
    primaryUrl: "postgresql://user:password@your-db-host:5432/saleor"
    # Optional: Add read replicas
    replicaUrls:
      - "postgresql://user:password@your-read-replica:5432/saleor"
```

### Important Notes About Database Passwords

- If you're using the built-in PostgreSQL and don't provide a password, a random one will be generated during the first installation
- The generated password will be preserved across Helm upgrades thanks to the `helm.sh/resource-policy: keep` annotation
- If you need to rotate the password:
  1. Delete the existing `postgresql-credentials` secret
  2. Either let the chart generate a new password or provide a new one in your values
  3. Upgrade the release

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