┌─────────────────────────────────────────────────────────────────────────┐
│               HELM DEPLOYMENT + KUBERNETEST ARCHITECTURE                │
└─────────────────────────────────────────────────────────────────────────┘

1. INPUT: Configuration Files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────┐     ┌─────────────────────────────┐
│  charts/saleor/Chart.yaml   │     │ saleor-staging-values.yaml  │
│  ───────────────────────    │     │  ───────────────────────    │
│  • Chart metadata           │     │  • Domain: saleor.staging   │
│  • Version info             │     │  • Secrets & passwords      │
│  • Dependencies:            │     │  • Resource limits          │
│    - PostgreSQL (Bitnami)   │────▶│  • PostgreSQL config        │
│    - Redis (Bitnami)        │     │  • Redis config             │
└─────────────────────────────┘     │  • Ingress: HTTP only       │
                                    └─────────────────────────────┘
┌─────────────────────────────┐                   │
│  charts/saleor/values.yaml  │                   │
│  ───────────────────────    │                   │
│  • Default values           │                   │
│  • Base configuration       │                   │
│  • Template defaults        │                   │
└─────────────────────────────┘                   │
          │                                       │
          └───────────────┬───────────────────────┘
                          │
                          │ Merged (staging overrides defaults)
                          ▼

2. HELM TEMPLATE ENGINE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────┐
│           charts/saleor/templates/ (Go Templates)               │
│  ─────────────────────────────────────────────────────────      │
│                                                                 │
│  ┌────────────────────┐  ┌────────────────────┐                 │
│  │  _helpers.tpl      │  │ configmap-         │                 │
│  │  ──────────────    │  │ settings.yaml      │                 │
│  │  • Shared logic    │  │ ──────────────     │                 │
│  │  • Name generators │  │ • Django settings  │                 │
│  │  • PUBLIC_URL:     │  │ • Environment vars │                 │
│  │    if tls → https  │  │                    │                 │
│  │    else → http ✓   │  │                    │                 │
│  └────────────────────┘  └────────────────────┘                 │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Deployments                                             │   │
│  │  ──────────────────────────────────────────────────      │   │
│  │  • saleor_deployment.yaml    → API pods                  │   │
│  │  • dashboard_deployment.yaml → Dashboard pods            │   │
│  │  • worker_deployment.yaml    → Celery workers            │   │
│  │  • beat_deployment.yaml      → Celery scheduler          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Other Resources                                         │   │
│  │  ────────────────────────────────────────────────        │   │
│  │  • ingress.yaml              → Nginx routing             │   │
│  │  • service_api.yaml          → API ClusterIP             │   │
│  │  • service_dashboard.yaml    → Dashboard ClusterIP       │   │
│  │  • secrets.yaml              → Credentials               │   │
│  │  • job_migrations.yaml       → DB migrations             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ Templates + Values = Kubernetes YAML
                          ▼

3. RENDERED KUBERNETES MANIFESTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────┐
│  Generated YAML sent to Kubernetes API                          │
│  ────────────────────────────────────────────────────────       │
│  • Deployment specs with env vars (PUBLIC_URL=http://...)       │
│  • Service definitions                                          │
│  • Ingress rules                                                │
│  • ConfigMaps & Secrets                                         │
│  • PersistentVolumeClaims                                       │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ helm install/upgrade
                          ▼

4. GKE CLUSTER (vapaus-europe-north1-staging)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────┐
│  Namespace: saleor                                              │
│  ───────────────────────────────────────────────────            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  Pods (Running Containers)                          │        │
│  │  ────────────────────────────────────────────────   │        │
│  │  • saleor-api          (Django REST/GraphQL)        │        │
│  │  • saleor-dashboard    (React SPA)                  │        │
│  │  • saleor-worker       (Celery tasks)               │        │
│  │  • saleor-celery-beat  (Celery scheduler)           │        │
│  │  • saleor-postgresql-0 (Database)                   │        │
│  │  • saleor-redis-master (Cache/Queue)                │        │
│  └─────────────────────────────────────────────────────┘        │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  Services (Internal Routing)                        │        │
│  │  ────────────────────────────────────────────────   │        │
│  │  • saleor-api:8000          → API pods              │        │
│  │  • saleor-dashboard:80      → Dashboard pods        │        │
│  │                                                     │        │
│  │  ClusterIP Services (Load-balanced):                │        │
│  │  • saleor-postgresql:5432   → PostgreSQL pod        │        │
│  │  • saleor-redis-master:6379 → Redis master pod      │        │
│  │                                                     │        │
│  │  Headless Services for StatefulSet:                 │        │
│  │  • saleor-postgresql-hl:5432   → For PostgreSQL     │        │
│  │  • saleor-redis-headless:6379  → For Redis          │        │
│  └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼

┌─────────────────────────────────────────────────────────────────┐
│  Namespace: ingress-nginx                                       │
│  ───────────────────────────────────────────────────            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  nginx-ingress-controller                           │        │
│  │  ────────────────────────────────────────────────   │        │
│  │  • Reads Ingress resource from 'saleor' namespace   │        │
│  │  • Routes traffic based on host/path:               │        │
│  │    - /graphql/   → saleor-api:8000                  │        │
│  │    - /dashboard/ → saleor-dashboard:80              │        │
│  │    - /thumbnail/ → saleor-api:8000                  │        │
│  └─────────────────────────────────────────────────────┘        │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────┐        │
│  │  LoadBalancer Service                               │        │
│  │  ────────────────────────────────────────────────   │        │
│  │  • Static IP: 35.228.65.250                         │        │
│  │  • Provisions GCP Network Load Balancer             │        │
│  └─────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼

5. EXTERNAL ACCESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────────────────────────────────────────────────────────────────┐
│  Google Cloud DNS                                               │
│  ────────────────────────────────────────────────────────       │
│  • saleor.staging-vapaus.com → 35.228.65.250                    │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  User Browser                                                   │
│  ────────────────────────────────────────────────────────       │
│  http://saleor.staging-vapaus.com/dashboard/                    │
│         │                                                       │
│         └─→ DNS lookup → 35.228.65.250                          │
│         └─→ HTTP request → LoadBalancer                         │
│         └─→ nginx routes to dashboard pod                       │
│         └─→ Dashboard makes GraphQL calls to API                │
└─────────────────────────────────────────────────────────────────┘