# K3s Infrastructure - GitOps Configuration

> **Complete infrastructure deployment for ZSEL Opole Technical School**  
> Managed via ArgoCD GitOps | 11 core services | 57 MikroTik devices | ~11.78TB storage

**Date:** 2025-11-22  
**ArgoCD Version:** 2.9+  
**GitOps Policy:** Automated sync with self-heal enabled

---

## 🚀 Quick Start

### Deploy Everything (5 minutes)

**Windows:**
```powershell
cd infrastruktura-k3s\gitops
.\deploy-infrastructure.ps1
```

**Linux/Mac:**
```bash
cd infrastruktura-k3s/gitops
chmod +x deploy-infrastructure.sh
./deploy-infrastructure.sh
```

**What gets deployed:**
- ✅ NTP + DNS (time sync + name resolution)
- ✅ Network AD + User AD (authentication domains)
- ✅ FreeRADIUS (device + WiFi auth)
- ✅ PacketFence (captive portal)
- ✅ Graylog (log aggregation, 90 days)
- ✅ Prometheus + Grafana + AlertManager (metrics + dashboards)
- ✅ Zabbix (SNMP monitoring)
- ✅ MinIO (S3 backup storage, 10TB)

📖 **Full guides:**
- **[DEPLOYMENT-QUICKSTART.md](./DEPLOYMENT-QUICKSTART.md)** - Quick start (5 min)
- **[DEPLOYMENT-ORDER.md](./DEPLOYMENT-ORDER.md)** - Full deployment guide
- **[SEALED-SECRETS-GUIDE.md](./SEALED-SECRETS-GUIDE.md)** - Secret management
- **[MIKROTIK-INTEGRATION.md](./MIKROTIK-INTEGRATION.md)** - MikroTik config

---

## 📂 Directory Structure

```
gitops/
├── README.md                          # This file
├── argocd/                            # ArgoCD configuration
│   ├── apps/                          # Application manifests
│   │   ├── core-auth-apps.yaml        # Samba AD + FreeRADIUS
│   │   ├── core-network-apps.yaml     # DNS + NTP + DHCP
│   │   ├── core-storage-apps.yaml     # MinIO
│   │   ├── mon-observability-apps.yaml # Prometheus + Grafana
│   │   ├── mon-logging-apps.yaml      # Graylog
│   │   └── mon-zabbix-apps.yaml       # Zabbix
│   ├── projects/                      # AppProject definitions
│   │   ├── core-services.yaml         # Core infrastructure services
│   │   └── monitoring.yaml            # Monitoring stack
│   └── app-of-apps.yaml               # Root Application (App of Apps pattern)
├── base/                              # Kustomize base manifests
│   ├── samba-ad/                      # Samba AD Domain Controller
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── freeradius/                    # FreeRADIUS Authentication
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap-ldap.yaml
│   │   ├── configmap-clients.yaml
│   │   ├── configmap-users.yaml
│   │   └── secret.yaml
│   ├── dns-bind9/                     # DNS Server
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap-named-conf.yaml
│   │   ├── configmap-zones.yaml
│   │   └── configmap-reverse-zones.yaml
│   ├── ntp-chrony/                    # NTP Server
│   │   ├── kustomization.yaml
│   │   ├── daemonset.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── graylog/                       # Log Aggregation
│   │   ├── kustomization.yaml
│   │   ├── statefulset-elasticsearch.yaml
│   │   ├── statefulset-mongodb.yaml
│   │   ├── deployment-graylog.yaml
│   │   ├── service-elasticsearch.yaml
│   │   ├── service-mongodb.yaml
│   │   ├── service-graylog.yaml
│   │   ├── pvc-elasticsearch.yaml
│   │   ├── pvc-mongodb.yaml
│   │   ├── configmap-graylog.yaml
│   │   └── secret.yaml
│   ├── prometheus/                    # Metrics Collection
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap-prometheus.yaml
│   │   ├── configmap-snmp-exporter.yaml
│   │   ├── configmap-alerts.yaml
│   │   └── deployment-snmp-exporter.yaml
│   ├── grafana/                       # Visualization
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap-dashboards.yaml
│   │   ├── configmap-datasources.yaml
│   │   └── secret.yaml
│   ├── alertmanager/                  # Alert Routing
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── zabbix/                        # Enterprise Monitoring
│   │   ├── kustomization.yaml
│   │   ├── statefulset-server.yaml
│   │   ├── statefulset-postgresql.yaml
│   │   ├── deployment-web.yaml
│   │   ├── daemonset-agent.yaml
│   │   ├── service-server.yaml
│   │   ├── service-web.yaml
│   │   ├── service-postgresql.yaml
│   │   ├── pvc-postgresql.yaml
│   │   ├── configmap-server.yaml
│   │   ├── configmap-web.yaml
│   │   └── secret.yaml
│   ├── minio/                         # S3 Backup Storage
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   ├── service-api.yaml
│   │   ├── service-console.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   └── dhcp-kea/                      # DHCP Server
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap-kea.yaml
│       └── configmap-reservations.yaml
├── overlays/                          # Environment-specific overrides
│   ├── dev/                           # Development environment
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/                       # Staging environment (optional)
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/                    # Production environment
│       ├── kustomization.yaml
│       ├── patches/
│       │   ├── samba-ad-resources.yaml
│       │   ├── prometheus-storage.yaml
│       │   └── zabbix-replicas.yaml
│       └── sealed-secrets/            # Encrypted secrets
│           ├── samba-ad-admin-sealed.yaml
│           ├── freeradius-secret-sealed.yaml
│           ├── zabbix-db-sealed.yaml
│           └── minio-credentials-sealed.yaml
└── docs/                              # Documentation
    ├── deployment-guide.md            # Step-by-step deployment
    ├── troubleshooting.md             # Common issues
    └── runbook.md                     # Operational procedures
```

---

## 🎯 GitOps Principles

### 1. Single Source of Truth
- All infrastructure defined in Git
- Manual changes via kubectl discouraged (ArgoCD will revert)
- All changes go through Git commit → PR → merge → auto-sync

### 2. Declarative Configuration
- Kubernetes manifests (YAML)
- Kustomize for templating (no Helm charts for network services)
- Environment-specific overlays (dev/staging/production)

### 3. Automated Sync
- ArgoCD monitors Git repository (polling interval: 3 minutes)
- Auto-sync enabled (optional manual approval for production)
- Self-heal: reverts manual changes within 5 minutes
- Prune: removes resources deleted from Git

### 4. Observability
- ArgoCD UI: https://argocd.zsel.internal
- Sync status per application
- Health checks (Green/Yellow/Red)
- Sync history + rollback capability

---

## 🏗️ Deployment Strategy

### Phase 1: Bootstrap ArgoCD
```bash
# Install ArgoCD on K3s cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Expose ArgoCD UI (MetalLB LoadBalancer)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Phase 2: Configure Repository
```bash
# Add Git repository to ArgoCD
argocd repo add https://github.com/zsel-opole/zsel-opole-org.git \
    --username git --password <GITHUB_TOKEN> \
    --name zsel-infra

# Or via SSH (recommended)
argocd repo add git@github.com:zsel-opole/zsel-opole-org.git \
    --ssh-private-key-path ~/.ssh/id_ed25519 \
    --name zsel-infra
```

### Phase 3: Deploy App of Apps
```bash
# Deploy root application (App of Apps pattern)
kubectl apply -f gitops/argocd/app-of-apps.yaml

# This will automatically create all child applications:
# - core-auth-apps (Samba AD, FreeRADIUS)
# - core-network-apps (DNS, NTP, DHCP)
# - core-storage-apps (MinIO)
# - mon-observability-apps (Prometheus, Grafana, AlertManager)
# - mon-logging-apps (Graylog)
# - mon-zabbix-apps (Zabbix)
```

### Phase 4: Verify Deployment
```bash
# Check all applications
argocd app list

# Expected output:
# NAME                    CLUSTER     NAMESPACE           STATUS  HEALTH
# app-of-apps             in-cluster  argocd              Synced  Healthy
# samba-ad                in-cluster  core-auth           Synced  Healthy
# freeradius              in-cluster  core-auth           Synced  Healthy
# dns-bind9               in-cluster  core-network        Synced  Healthy
# ntp-chrony              in-cluster  core-network        Synced  Healthy
# dhcp-kea                in-cluster  core-network        Synced  Healthy
# minio                   in-cluster  core-storage        Synced  Healthy
# prometheus              in-cluster  mon-observability   Synced  Healthy
# grafana                 in-cluster  mon-observability   Synced  Healthy
# alertmanager            in-cluster  mon-observability   Synced  Healthy
# graylog                 in-cluster  mon-logging         Synced  Healthy
# zabbix                  in-cluster  mon-zabbix          Synced  Healthy

# Check specific application details
argocd app get samba-ad

# Sync manually (if auto-sync disabled)
argocd app sync samba-ad
```

---

## 🔄 Workflow

### Making Changes

**1. Create Feature Branch:**
```bash
git checkout -b feature/update-prometheus-retention
```

**2. Edit Manifests:**
```bash
# Example: Increase Prometheus retention from 90 to 180 days
vim gitops/base/prometheus/configmap-prometheus.yaml

# Add retention configuration:
storage:
  tsdb:
    retention.time: 180d
```

**3. Test Locally (Optional):**
```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f gitops/base/prometheus/

# Kustomize build test
kubectl kustomize gitops/overlays/production/ | less
```

**4. Commit & Push:**
```bash
git add gitops/base/prometheus/configmap-prometheus.yaml
git commit -m "feat(prometheus): increase retention to 180 days for compliance"
git push origin feature/update-prometheus-retention
```

**5. Create Pull Request:**
- GitHub UI: Create PR from feature branch → main
- Request review from IT team
- CI pipeline runs:
  - YAML linting (yamllint)
  - Kustomize validation
  - Security scan (Trivy)

**6. Merge to Main:**
- After approval, merge PR
- ArgoCD detects change within 3 minutes
- Auto-sync applies changes to cluster
- Monitor in ArgoCD UI

**7. Verify Deployment:**
```bash
# Check sync status
argocd app get prometheus

# Watch rollout
kubectl rollout status statefulset/prometheus -n mon-observability

# Verify retention
kubectl exec -n mon-observability prometheus-0 -- promtool tsdb analyze /prometheus
```

### Rollback Procedure

**Option 1: Via ArgoCD UI**
1. Open application in ArgoCD UI
2. Click "History" tab
3. Select previous healthy revision
4. Click "Rollback"

**Option 2: Via Git Revert**
```bash
# Revert last commit
git revert HEAD
git push origin main

# ArgoCD auto-syncs to previous state
```

**Option 3: Via kubectl (emergency only)**
```bash
# Disable auto-sync temporarily
argocd app set prometheus --sync-policy none

# Manual rollback
kubectl rollout undo statefulset/prometheus -n mon-observability

# Re-enable auto-sync (after fixing issue in Git)
argocd app set prometheus --sync-policy automated
```

---

## 📊 Health Checks

### Application Health
ArgoCD evaluates health based on:
- **Pod status:** Running + Ready
- **StatefulSet:** All replicas ready
- **Deployment:** All replicas ready
- **Service:** Endpoints available
- **PVC:** Bound to PersistentVolume

**Custom Health Checks:**
```yaml
# Example: Samba AD health check
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: samba-ad
spec:
  ignoreDifferences:
    - group: apps
      kind: StatefulSet
      jsonPointers:
        - /spec/volumeClaimTemplates  # Ignore PVC changes
  
  # Custom health check
  healthChecks:
    - tcpSocket:
        port: 389  # LDAP port
      initialDelaySeconds: 60
      periodSeconds: 10
```

---

## 🔐 Secrets Management

### Sealed Secrets (Recommended)
```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubectl create secret generic samba-ad-admin \
    --from-literal=password='SECURE_PASSWORD' \
    --dry-run=client -o yaml | \
    kubeseal -o yaml > gitops/overlays/production/sealed-secrets/samba-ad-admin-sealed.yaml

# Commit sealed secret to Git (safe - encrypted)
git add gitops/overlays/production/sealed-secrets/samba-ad-admin-sealed.yaml
git commit -m "chore: add sealed secret for Samba AD admin"
```

### External Secrets Operator (Alternative)
```bash
# Store secrets in external vault (Azure Key Vault, HashiCorp Vault)
# ArgoCD pulls secrets at runtime
```

---

## 🚨 Troubleshooting

### App Stuck in "OutOfSync"
```bash
# Check diff
argocd app diff prometheus

# Force sync
argocd app sync prometheus --force

# Ignore specific differences
argocd app set prometheus --ignore-difference /spec/replicas
```

### App Stuck in "Progressing"
```bash
# Check pod logs
kubectl logs -n mon-observability -l app=prometheus

# Check events
kubectl get events -n mon-observability --sort-by='.lastTimestamp'

# Describe problematic resource
kubectl describe statefulset prometheus -n mon-observability
```

### Auto-Sync Not Working
```bash
# Verify webhook (if using GitHub webhook instead of polling)
argocd repo get https://github.com/zsel-opole/zsel-opole-org.git

# Force refresh
argocd app refresh prometheus

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

---

## 📖 References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [GitOps Principles](https://opengitops.dev/)

---

**Status:** 🟡 In Development  
**Owner:** Łukasz Kołodziej (Cloud Architect)  
**Last Updated:** 2025-11-22
