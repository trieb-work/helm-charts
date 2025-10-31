# Saleor Staging Deployment Guide

## Prerequisites

### Step 1: Setup Google Kubernetes Engine (GKE) cluster

**In Google Cloud Console:**

1. Go to **Kubernetes Engine** → **Clusters**
2. Click **Create**
3. Select **Autopilot**
4. Select **Region** to be `europe-north1` and create a name for the cluster, e.g. `vapaus-europe-north1-staging`
5. Check other settings.
6. Click **Create**

### Step 2: Setup local development environment

```bash
# Install kubectl
brew install kubectl
# Install helm
brew install helm
# Install gcloud
brew install gcloud
# Install gcloud components (if missing)
gcloud components install gke-gcloud-auth-plugin
# Get credentials for the cluster
gcloud container clusters get-credentials vapaus-europe-north1-staging --region europe-north1 --project staging-364405

# Optional tools:
# Install kubie (compare to kubectx, it can switch context per terminal session)
brew install kubie
# Install k9s (compare to kubectl, it provides a terminal UI)
brew install k9s
```

### Step 3: Grant Cluster Admin Permissions

You need **Kubernetes Engine Admin** role to create cluster-wide resources (ingress controller, etc.).

**In Google Cloud Console:**

1. Go to **IAM & Admin** → **IAM**
2. Find your user
3. Click **Edit** (pencil icon)
4. Click **ADD ANOTHER ROLE**
5. Search for and add: **Kubernetes Engine Admin** (`roles/container.admin`)
6. Click **Save**

**Alternative: Ask a project owner to run:**

```bash
gcloud projects add-iam-policy-binding staging-364405 \
  --member="user:taiquan@vapaus.io" \
  --role="roles/container.admin"
```

### Step 4: Verify Your Setup

```bash
# Check you're connected to the right cluster
kubectl config current-context

# Check kubectl works
kubectl get nodes

# Check helm is installed
helm version
```

## Deployment

### Step 1: Refresh Credentials (if not already done)

```bash
gcloud container clusters get-credentials vapaus-europe-north1-staging \
  --region europe-north1 \
  --project staging-364405
```

### Step 2: Grant Cluster Admin Access

```bash
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user=taiquan@vapaus.io
```

### Step 3: Create Redis Secret (Important!)

Due to a known issue with the Bitnami Redis chart where passwords can be double-encoded, we need to manually create the Redis secret before deploying:

```bash
# Create namespace if it doesn't exist
kubectl create namespace saleor --dry-run=client -o yaml | kubectl apply -f -

# Create Redis secret with correct password format
kubectl create secret generic saleor-redis -n saleor \
  --from-literal=redis-password='Bktv1G9qJnYDz7fp9QO6xOPY9o6HfJXh'
```

**Why is this needed?** The Bitnami Helm chart can sometimes store the Redis password with extra encoding/quotes, causing authentication failures. By creating the secret manually, we ensure the password is stored correctly.

### Step 4: Reserve a static IP

**In Google Cloud Console:**

1. Go to **Networking** → **Addresses**
2. Click **Create Address**
3. Enter a name for the address, e.g. `saleor-staging-ingress-ip`
4. Select the region to be `europe-north1`
5. Select the project to be `staging-364405`
6. Click **Create**

or run the following command:

```bash
# Reserve a new static IP
gcloud compute addresses create saleor-ENV-ingress-ip \
  --region REGION \
  --project PROJECT_ID
```

Then get the reserved IP:

```bash
gcloud compute addresses describe saleor-staging-ingress-ip \
  --region REGION \
  --project PROJECT_ID \
  --format="value(address)"
```

### Promote Ephemeral IP to Static

If you already have a LoadBalancer with an ephemeral IP that you want to keep:

```bash
# Get current IP
CURRENT_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Current LoadBalancer IP: $CURRENT_IP"

# Reserve it as static (note: this may fail if the IP is already in use)
gcloud compute addresses create saleor-ENV-ingress-ip \
  --addresses $CURRENT_IP \
  --region REGION \
  --project PROJECT_ID

# Then update nginx-ingress to use it
helm upgrade nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.loadBalancerIP=$CURRENT_IP \
  --reuse-values
```

### Step 5: Install nginx-ingress-controller

We use the pre-reserved static IP (`35.228.65.250` in `staging-364405` project) from
the previous step to ensure the LoadBalancer IP doesn't change.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.service.loadBalancerIP=35.228.65.250
```

Wait for LoadBalancer IP:

```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -w
```

Note the `EXTERNAL-IP` when it appears (takes 2-3 minutes).

### Step 6: Deploy Saleor

```bash
helm install saleor ./charts/saleor \
  --values saleor-staging-values.yaml \
  --namespace saleor \
  --create-namespace
```

### Step 7: Monitor Deployment

```bash
# Watch pods starting up
kubectl get pods -n saleor -w

# Check all resources
kubectl get all -n saleor

# Check migration job
kubectl get jobs -n saleor

# View logs if needed
kubectl logs -n saleor deployment/saleor-api
```

## Post-Deployment Configuration

### 1. Configure DNS

Once you have the LoadBalancer IP from nginx-ingress:

**In Google Cloud Console:**

1. Go to **Network Services** → **Cloud DNS**
2. Select your `staging-vapaus.com` zone
3. Click **Add Record Set**
   - Name: `saleor`
   - Resource Record Type: A
   - TTL: 300
   - IPv4 Address: [pre-reserved static IP e.g. 35.228.65.250]
   - Click **Create**

**Wait 5-10 minutes** for DNS propagation.

### 2. Create SaleorSuperuser Account

Once pods are running and DNS is configured:

```bash
# Get the API pod name
POD=$(kubectl get pod -n saleor -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")

# Create superuser
kubectl exec -it -n saleor $POD -- python manage.py createsuperuser
```

Follow the prompts to enter:
- Email address (this will be your username)
- Password (minimum 8 characters)

### 3. Access Saleor

After DNS propagation:

- **Dashboard:** http://saleor.staging-vapaus.com/dashboard/
- **GraphQL API (and playground):** http://saleor.staging-vapaus.com/graphql/

### 4. Configure Cloud Run Integration

Your Cloud Run app can make GraphQL requests to:

```
http://saleor-api.staging-vapaus.com/graphql/
```

**If you encounter CORS issues**, update the values file:

```yaml
api:
  extraEnv:
    - name: ALLOWED_CLIENT_HOSTS
      value: "saleor-dashboard.staging-vapaus.com,your-cloudrun-app.staging-vapaus.com"
```

Then upgrade the deployment:

```bash
helm upgrade saleor ./charts/saleor \
  --values saleor-staging-values.yaml \
  --namespace saleor
```

## Configuration Details

### Secrets

**In `saleor-staging-values.yaml`:**
- Django Secret Key (50 chars)
- JWT RSA Private Key (for JWT signing in production mode)

**Manually created Kubernetes secrets:**
- `saleor-postgresql` - PostgreSQL passwords (postgres-password, user-password, replication-password)
- `saleor-redis` - Redis password

### Images

- **Saleor API:** `ghcr.io/saleor/saleor:3.21.8`
- **Dashboard:** `ghcr.io/saleor/saleor-dashboard:3.21.3`
- **PostgreSQL:** `bitnamilegacy/postgresql:16.4.0-debian-12-r9` ⚠️
- **Redis:** `bitnamilegacy/redis:7.4.1-debian-12-r3` ⚠️

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|-------------|-----------|----------------|--------------|---------|
| **API** | 500m | 1000m | 1Gi | 2Gi | - |
| **Dashboard** | 250m | 500m | 256Mi | 512Mi | - |
| **Worker** | 250m | 1000m | 1Gi | 2Gi | - |
| **Beat** | 100m | 200m | 128Mi | 256Mi | - |
| **PostgreSQL** | 500m | 1000m | 1Gi | 2Gi | 20Gi |
| **Redis** | 100m | 250m | 128Mi | 256Mi | 8Gi |

### Components

- **Saleor API** - GraphQL API server (1 replica)
- **Saleor Dashboard** - Admin web interface (1 replica)
- **Celery Worker** - Background task processor (1 replica)
- **Celery Beat** - Task scheduler
- **PostgreSQL** - Database (standalone, persistent volume)
- **Redis** - Cache and message broker (standalone, persistent volume)
- **nginx-ingress** - Load balancer and ingress controller
- **Migration Job** - Automatic database migrations on install/upgrade


## Useful Commands

See [quick-reference-cheatsheet.md](quick-reference-cheatsheet.md) for more commands.

## Alternatives to Bitnami Legacy Images

⚠️ **Current setup uses `bitnamilegacy` images which receive no security updates.** For production, choose one of these options:

### Option 1: Managed Services

Use Google Cloud managed services instead of in-cluster databases:

```yaml
# saleor-staging-values.yaml
postgresql:
  enabled: false

redis:
  enabled: false

global:
  database:
    host: "10.x.x.x"  # Cloud SQL private IP
    port: 5432
    name: saleor
    username: saleor
    password: "..."  # Or use Secret Manager

  redis:
    host: "10.x.x.x"  # Memorystore IP
    port: 6379
```

**Pros:** Automatic backups, high availability, security patches, less operational overhead
**Cost:** ~$50-200/month depending on size

### Option 2: Official Images + CloudNativePG

Use official PostgreSQL/Redis images with production-ready operators:

**PostgreSQL:** [CloudNativePG](https://cloudnative-pg.io/)
```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

**Redis:** [Redis HA Chart](https://github.com/DandyDeveloper/charts/tree/master/charts/redis-ha)
```bash
helm repo add dandydeveloper https://dandydeveloper.github.io/charts
helm install redis dandydeveloper/redis-ha --namespace saleor
```

**Pros:** Free, open-source, production-ready operators with HA support
**Cons:** Requires configuration changes to connect Saleor

### Option 3: Bitnami Secure Images (Commercial)

Subscribe to [Bitnami Secure Images](https://www.arrow.com/globalecs/uk/products/bitnami-secure-images/):

```yaml
postgresql:
  image:
    registry: registry.bitnami.com  # Private registry with subscription
    repository: postgresql
    tag: "16.4.0"

redis:
  image:
    registry: registry.bitnami.com
    repository: redis
    tag: "7.4.1"
```

**Pros:** Drop-in replacement, hardened images, SLSA Level 3, enterprise support
**Cost:** Commercial subscription (contact Arrow for pricing)

## Next Steps

### Multi-Environment Deployment

**Goal:** Deploy Saleor to all environments (Production, Staging, Development, Demo) with CI/CD automation.

#### 1. Repository Structure

Move Saleor manifests to `vapaus` repo for version control with application code:

```
vapaus/
├── .github/
│   └── workflows/
│       ├── saleor_deploy_staging.yml     # Deploy to staging on merge to main
│       ├── saleor_deploy_prod.yml        # Deploy to production (manual trigger)
│       ├── saleor_feature_create.yml     # Create feature env on 'feature-saleor' label
│       └── saleor_feature_destroy.yml    # Cleanup on PR close
├── saleor/
│   ├── values/
│   │   ├── base.yaml                     # Shared configuration
│   │   ├── staging.yaml                  # Staging overrides
│   │   ├── production.yaml               # Production overrides
│   │   ├── development.yaml              # Development overrides
│   │   ├── demo.yaml                     # Demo overrides
│   │   └── feature.yaml.template         # Template for feature envs
│   └── scripts/
│       ├── deploy.sh                     # Deployment helper script
│       └── db-copy.sh                    # Database copy utility
```

#### 2. CI/CD Workflow Pattern

**Feature Environment Creation** (triggered by `feature-saleor` label):

```yaml
# .github/workflows/saleor_feature_create.yml
# All feature environments live in the development project
1. Export Saleor DB from staging (staging-364405 project)
   - Auth to staging project
   - gcloud sql export sql saleor-staging-instance → gs://staging-bucket/dump.sql
2. Copy to development project bucket
   - gsutil cp gs://staging-bucket/dump.sql → gs://dev-bucket/
3. Authenticate to development project
   - Auth to development project
   - gcloud container clusters get-credentials vapaus-europe-north1-dev
4. Create Kubernetes namespace in dev cluster
   - kubectl create namespace saleor-pr-<number>
5. Create PostgreSQL database in dev Cloud SQL instance
   - gcloud sql databases create saleor-pr-<number> --instance=vapaus-dev-instance
6. Import staging data to feature database
   - gcloud sql import sql vapaus-dev-instance gs://dev-bucket/dump.sql
     --database=saleor-pr-<number>
7. Generate feature-specific Helm values
   - Override: database name, Redis namespace, ingress host
8. Deploy with Helm to dev cluster
   - helm install saleor-pr-<number> ./charts/saleor
     --namespace saleor-pr-<number>
     --values values/base.yaml
     --values values/feature.yaml
9. Run migrations
   - kubectl exec -n saleor-pr-<number> -- python manage.py migrate
10. Comment PR with URLs
    - Dashboard: https://saleor-api-pr-<number>.dev-vapaus.com/dashboard/
    - GraphQL: https://saleor-api-pr-<number>.dev-vapaus.com/graphql/
```

**Feature Environment Cleanup** (on PR close, in development project):

```yaml
# .github/workflows/saleor_feature_destroy.yml
1. Authenticate to development project
   - Auth to development project
2. Delete Helm release from dev cluster
   - helm uninstall saleor-pr-<number> -n saleor-pr-<number>
3. Delete Kubernetes namespace from dev cluster
   - kubectl delete namespace saleor-pr-<number>
4. Drop PostgreSQL database from dev instance
   - gcloud sql databases delete saleor-pr-<number> --instance=vapaus-dev-instance -q
5. Notify Slack
```

#### 3. Infrastructure per Environment

| Resource | Staging | Production | Development + Features |
|----------|---------|------------|------------------------|
| **GCP Project** | staging-364405 | production-xxx | development-xxx |
| **GKE Cluster** | vapaus-europe-north1-staging | vapaus-europe-north1-prod | vapaus-europe-north1-dev (shared) |
| **Namespace** | `saleor` | `saleor` | `saleor-pr-<number>` (feature) |
| **PostgreSQL** | Cloud SQL instance | Cloud SQL instance | Shared Cloud SQL instance (dev) |
| **Database** | `saleor` | `saleor` | `saleor-pr-<number>` (feature) |
| **Redis** | Memorystore (shared) | Memorystore (shared) | Memorystore (shared) or in-cluster |
| **Ingress** | saleor.staging-vapaus.com | saleor.vapaus.io | saleor-pr-N.dev-vapaus.com |
| **DNS** | Cloud DNS (staging zone) | Cloud DNS (prod zone) | Cloud DNS (dev zone) |

**Note:** Feature environments (per-PR) live in the **development project**, sharing the same GKE cluster and Cloud SQL instance as the main development environment, but with isolated namespaces and databases.

#### 4. Database Copy Strategy

Reuse existing pattern from `feature_create_env.yml` (lines 47-139):

```bash
# Feature environments share the development project's Cloud SQL instance

# 1. Export from source environment (Staging project: staging-364405)
gcloud sql export sql saleor-staging-instance \
  gs://saleor-staging-db-export/saleor-staging.sql \
  --database=saleor \
  --project=staging-364405

# 2. Copy between projects (Staging → Development)
gsutil cp gs://saleor-staging-db-export/saleor-staging.sql \
          gs://saleor-dev-db-export/

# 3. Import to development project Cloud SQL instance
# Each feature environment gets its own database in the shared instance
gcloud sql import sql vapaus-dev-instance \
  gs://saleor-dev-db-export/saleor-staging.sql \
  --database=saleor-pr-<number> \
  --project=development-project-id
```

**Why this works:**
- Feature environments live in the **development project**
- Shared Cloud SQL instance (`vapaus-dev-instance`) in development project
- Each PR gets its own database: `saleor-pr-<number>` (isolated data)
- Fast setup: Copy staging data to test catalog features with realistic data
- Automatic cleanup on PR close (no orphaned resources)

#### 5. Integration with Existing Setup

**Cloud Run ↔ Saleor Communication:**

Your existing Cloud Run apps can call Saleor GraphQL API:

```yaml
# In your Cloud Run environment variables
SALEOR_API_URL: "https://saleor.staging-vapaus.com/graphql/"

# For feature environments
SALEOR_API_URL: "https://saleor-api-pr-<number>.dev-vapaus.com/graphql/"
```

Add to CORS configuration in Saleor values:

```yaml
# saleor/values/development.yaml
api:
  extraEnv:
    - name: ALLOWED_CLIENT_HOSTS
      value: "saleor.dev-vapaus.com,api-*.dev-vapaus.com,user-*.dev-vapaus.com"
```

#### 6. Implementation Checklist

- [ ] Create `vapaus/saleor/` directory structure
- [ ] Copy current Helm values and split into base + environment-specific files
- [ ] Create GitHub Actions workflows (staging, prod, feature create/destroy)
- [ ] Setup GKE clusters for each environment (if not exists)
- [ ] Configure Cloud SQL instances or use managed PostgreSQL
- [ ] Setup Memorystore Redis instances (optional)
- [ ] Configure DNS zones and wildcard certificates
- [ ] Setup GCP service accounts and IAM permissions for workflows
- [ ] Test feature environment creation on a test PR
- [ ] Document workflow triggers and environment access

### For production deployment, also required

1. **Replace Bitnami Legacy Images**
   - Migrate to Option 1, 2, or 3 above
   - Test thoroughly before production deployment

2. **Enable TLS/HTTPS**
   - Install cert-manager
   - Configure Let's Encrypt
   - Update ingress with TLS configuration

3. **Use Google Cloud Storage**
   - Configure GCS buckets for media files
   - Enable Workload Identity for secure access

4. **Scale Resources**
   - Increase replica counts
   - Enable horizontal pod autoscaling
   - Increase resource limits

5. **Monitoring & Logging** (optional)
   - Set up Google Cloud Monitoring
   - Configure log aggregation
   - Set up alerts

6. **Private Networking** (optional)
   - Use Internal Load Balancer
   - VPC-native networking
   - Private communication with Cloud Run

## Support

For Saleor-specific issues:
- Documentation: https://docs.saleor.io
- Community: https://saleor.io/community/
- GitHub: https://github.com/saleor/saleor

For GKE issues:
- Documentation: https://cloud.google.com/kubernetes-engine/docs

