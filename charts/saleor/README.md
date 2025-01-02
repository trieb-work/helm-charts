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
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-saleor-role
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