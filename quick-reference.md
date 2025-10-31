# Saleor Staging - Quick Reference

## 🚀 One-Command Deployment

```bash
git clone git@github.com:Vapaus-io/saleor-helm-charts.git
cd saleor-deploy-to-staging-poc
./deploy-saleor-staging.sh
```

## 🔑 Access URLs

- **Dashboard:** http://saleor.staging-vapaus.com/dashboard/
- **GraphQL API:** http://saleor.staging-vapaus.com/graphql/

## 📊 Status Checks

```bash
# Quick overview
kubectl get pods -n saleor

# All resources
kubectl get all -n saleor

# LoadBalancer IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller

# Resource usage
kubectl top pods -n saleor
```

## 👤 Superuser Management

```bash
# Create superuser
POD=$(kubectl get pod -n saleor -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it -n saleor $POD -- python manage.py createsuperuser

# Access Django shell
kubectl exec -it -n saleor $POD -- python manage.py shell

# List users
kubectl exec -it -n saleor $POD -- python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print([u.email for u in User.objects.all()])"
```

## 📝 View Logs

```bash
# API logs
kubectl logs -n saleor deployment/saleor-api -f

# Dashboard logs
kubectl logs -n saleor deployment/saleor-dashboard -f

# Worker logs
kubectl logs -n saleor deployment/saleor-worker -f

# PostgreSQL logs
kubectl logs -n saleor saleor-postgresql-0 -f

# All API pod logs (if multiple replicas)
kubectl logs -n saleor -l app.kubernetes.io/component=api --all-containers=true -f
```

## 🔄 Update & Restart

```bash
# Update deployment after changing values
helm upgrade saleor ./charts/saleor \
  --values saleor-staging-values.yaml \
  --namespace saleor
#  --dry-run

# Restart specific deployment (no downtime with multiple replicas)
kubectl rollout restart deployment/saleor-api -n saleor
kubectl rollout restart deployment/saleor-dashboard -n saleor
kubectl rollout restart deployment/saleor-worker -n saleor

# Check rollout status
kubectl rollout status deployment/saleor-api -n saleor
```

## 📈 Scaling

```bash
# Scale API horizontally
kubectl scale deployment saleor-api -n saleor --replicas=3

# Scale workers
kubectl scale deployment saleor-worker -n saleor --replicas=2

# Check current replicas
kubectl get deployment -n saleor
```

## 🗄️ Database Operations

```bash
# Connect to PostgreSQL
PG_POD=$(kubectl get pod -n saleor -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it -n saleor $PG_POD -- psql -U saleor -d saleor

# Run Django migrations manually
POD=$(kubectl get pod -n saleor -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it -n saleor $POD -- python manage.py migrate

# Create database backup
kubectl exec -n saleor $PG_POD -- pg_dump -U saleor saleor > saleor-backup-$(date +%Y%m%d).sql

# View migration status
kubectl exec -it -n saleor $POD -- python manage.py showmigrations
```

## 🔧 Troubleshooting

```bash
# Describe pod (shows events and errors)
kubectl describe pod -n saleor [POD_NAME]

# Get recent events
kubectl get events -n saleor --sort-by='.lastTimestamp' | tail -20

# Check ingress
kubectl describe ingress -n saleor

# Check persistent volumes
kubectl get pvc -n saleor

# Port forward for local testing (bypasses ingress)
kubectl port-forward -n saleor svc/saleor-api 8000:8000
# Then access: http://localhost:8000/graphql/
```

## 🧹 Cleanup

```bash
# Delete Saleor (keeps PVCs for data safety)
helm uninstall saleor -n saleor

# Delete everything including data
kubectl delete namespace saleor

# Delete nginx-ingress (releases LoadBalancer IP)
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx
```

## 🔐 Secrets Management

```bash
# View secrets (encoded)
kubectl get secrets -n saleor

# Decode a secret
kubectl get secret saleor-secrets -n saleor -o jsonpath="{.data.SECRET_KEY}" | base64 -d

# Update a secret
kubectl edit secret saleor-secrets -n saleor
```

## 📦 Helm Operations

```bash
# List installed releases
helm list -n saleor

# Get values for current deployment
helm get values saleor -n saleor

# View all values (including defaults)
helm get values saleor -n saleor --all

# History of releases
helm history saleor -n saleor

# Rollback to previous version
helm rollback saleor -n saleor

# Dry run upgrade (see what would change)
helm upgrade saleor ./charts/saleor \
  --values saleor-staging-values.yaml \
  --namespace saleor \
  --dry-run --debug
```

## 🧪 Testing GraphQL API

```bash
# Test API health
curl http://saleor-api.staging-vapaus.com/health/

# Simple GraphQL query
curl -X POST http://saleor-api.staging-vapaus.com/graphql/ \
  -H "Content-Type: application/json" \
  -d '{"query": "{ shop { name } }"}'

# From Cloud Run (replace with your Cloud Run URL)
curl -X POST http://saleor-api.staging-vapaus.com/graphql/ \
  -H "Content-Type: application/json" \
  -H "Origin: https://your-app.staging-vapaus.com" \
  -d '{"query": "{ shop { name } }"}'
```

## 📊 Resource Monitoring

```bash
# Current resource usage
kubectl top pods -n saleor
kubectl top nodes

# Watch resource usage in real-time
watch kubectl top pods -n saleor

# Check resource limits
kubectl describe pod -n saleor [POD_NAME] | grep -A 5 "Limits:"
```

## 🌐 DNS & Static IP

```bash
# Check LoadBalancer's current IP
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check reserved static IP
gcloud compute addresses describe saleor-staging-ingress-ip \
  --region europe-north1 \
  --project staging-364405 \
  --format="value(address)"

# List all static IPs
gcloud compute addresses list --filter="region:europe-north1" --project staging-364405

# Check DNS resolution
nslookup saleor.staging-vapaus.com

# Test API accessibility
curl -I http://saleor.staging-vapaus.com/graphql/

# Test dashboard accessibility
curl -I http://saleor.staging-vapaus.com/dashboard/
```

## 🔧 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n saleor

# Describe specific pod
kubectl describe pod -n saleor [POD_NAME]

# View pod logs
kubectl logs -n saleor [POD_NAME]

# View previous logs if pod crashed
kubectl logs -n saleor [POD_NAME] --previous
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n saleor
kubectl describe ingress -n saleor

# Check nginx-ingress controller logs
kubectl logs -n ingress-nginx deployment/nginx-ingress-ingress-nginx-controller
```

### Database Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n saleor -l app.kubernetes.io/name=postgresql

# View PostgreSQL logs
kubectl logs -n saleor saleor-postgresql-0

# Check migration job
kubectl get jobs -n saleor
kubectl logs -n saleor job/saleor-migration
```

### Redis Authentication Issues

If you see errors like "invalid username-password pair" in worker logs:

```bash
# Check if Redis secret exists and has correct format
kubectl get secret saleor-redis -n saleor -o jsonpath="{.data.redis-password}" | base64 -d
# Should output: Bktv1G9qJnYDz7fp9QO6xOPY9o6HfJXh (without quotes)

# If the secret has quotes or double-encoding, recreate it:
kubectl delete secret saleor-redis -n saleor
kubectl create secret generic saleor-redis -n saleor \
  --from-literal=redis-password='Bktv1G9qJnYDz7fp9QO6xOPY9o6HfJXh'

# Then delete Redis pod to force recreation with correct password:
kubectl delete pod saleor-redis-master-0 -n saleor

# Check worker logs after Redis restarts:
kubectl logs -n saleor -l app.kubernetes.io/component=worker -f
```

### Permission Denied Errors

If you still get permission errors after adding the role:

1. Wait a few minutes (IAM changes can take time to propagate)
2. Refresh credentials:
   ```bash
   gcloud container clusters get-credentials vapaus-europe-north1-staging \
     --region europe-north1 \
     --project staging-364405
   ```
3. Try the command again

### Starting Over

If something goes wrong and you want to start fresh:

```bash
# Uninstall Saleor
helm uninstall saleor -n saleor

# Delete the namespace (this removes all resources and data)
kubectl delete namespace saleor

# Optionally, uninstall nginx-ingress too
helm uninstall nginx-ingress -n ingress-nginx
kubectl delete namespace ingress-nginx

# Then run the deployment script again
./deploy-saleor-staging.sh
```

## 💾 Backup Strategy

```bash
# Backup PostgreSQL database
PG_POD=$(kubectl get pod -n saleor -l app.kubernetes.io/name=postgresql -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n saleor $PG_POD -- pg_dump -U saleor saleor | gzip > saleor-backup-$(date +%Y%m%d-%H%M%S).sql.gz

# List persistent volume claims
kubectl get pvc -n saleor

# Create snapshot of PVC (GKE)
# This is done through Google Cloud Console or gcloud CLI
```

## 🎯 Common Tasks

### Update Environment Variables

1. Edit `saleor-staging-values.yaml`
2. Modify the `extraEnv` section under `api:`
3. Run: `helm upgrade saleor ./charts/saleor --values saleor-staging-values.yaml --namespace saleor`

### Add Cloud Run Domain to CORS

Edit `saleor-staging-values.yaml`:

```yaml
api:
  extraEnv:
    - name: ALLOWED_CLIENT_HOSTS
      value: "saleor-dashboard.staging-vapaus.com,your-app.staging-vapaus.com"
```

Then upgrade: `helm upgrade saleor ./charts/saleor --values saleor-staging-values.yaml --namespace saleor`

### Check Migration Job Status

```bash
kubectl get jobs -n saleor
kubectl logs -n saleor job/saleor-migration
```

### Execute Django Management Commands

```bash
POD=$(kubectl get pod -n saleor -l app.kubernetes.io/component=api -o jsonpath="{.items[0].metadata.name}")

# Examples:
kubectl exec -it -n saleor $POD -- python manage.py help
kubectl exec -it -n saleor $POD -- python manage.py populatedb
kubectl exec -it -n saleor $POD -- python manage.py createsuperuser
kubectl exec -it -n saleor $POD -- python manage.py clear_cache
```

## 📞 Getting Help

- Full guide: `STAGING-DEPLOYMENT-GUIDE.md`
- Saleor docs: https://docs.saleor.io
- Kubernetes docs: https://kubernetes.io/docs
- Helm docs: https://helm.sh/docs

